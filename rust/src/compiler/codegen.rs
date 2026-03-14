//! JS 代码生成 — AST → JS render 函数。
//!
//! 将模板 AST 转换为可执行的 JS render 函数字符串。
//! 生成的 render 函数通过 `this` 访问组件数据/方法，
//! 返回符合 VNode 格式的 JS 对象树。

use super::ast::*;

/// 将 AST 生成为 JS render 函数代码。
///
/// 输出格式:
/// ```javascript
/// function render() {
///     var _id = 0;
///     function _h(type, props, style, events, children) { ... }
///     // ... 生成代码 ...
///     return _h("view", ...);
/// }
/// ```
pub fn generate(root: &TemplateRoot) -> Result<String, String> {
    let mut ctx = CodeGenContext::new();

    // 生成子节点代码
    let children_code = gen_children(&root.children, &mut ctx)?;

    // 组装 render 函数
    let js = format!(
        r#"function render() {{
    var _id = 0;
    function _h(type, props, style, events, children) {{
        return {{ id: ++_id, type: type, props: props || {{}}, style: style || {{}}, events: events || {{}}, children: children || [] }};
    }}
    {children_code}
}}"#
    );

    Ok(js)
}

struct CodeGenContext {
    indent: usize,
}

impl CodeGenContext {
    fn new() -> Self {
        Self { indent: 1 }
    }

    fn indent_str(&self) -> String {
        "    ".repeat(self.indent)
    }
}

/// 生成子节点列表代码，返回最终的返回表达式。
fn gen_children(children: &[TemplateChild], ctx: &mut CodeGenContext) -> Result<String, String> {
    if children.is_empty() {
        return Ok(format!("{}return _h(\"view\", {{}}, {{}}, {{}}, []);", ctx.indent_str()));
    }

    // 单根节点
    if children.len() == 1 {
        return match &children[0] {
            TemplateChild::Element(node) => {
                let expr = gen_element(node, ctx)?;
                Ok(format!("{}return {};", ctx.indent_str(), expr))
            }
            TemplateChild::Text(text) => {
                let escaped = escape_js_string(text);
                Ok(format!(
                    "{}return _h(\"text\", {{content: \"{escaped}\"}}, {{}}, {{}}, []);",
                    ctx.indent_str()
                ))
            }
            TemplateChild::Interpolation(expr) => Ok(format!(
                "{}return _h(\"text\", {{content: String(this.{expr})}}, {{}}, {{}}, []);",
                ctx.indent_str()
            )),
            TemplateChild::Comment(_) => Ok(format!(
                "{}return _h(\"view\", {{}}, {{}}, {{}}, []);",
                ctx.indent_str()
            )),
        };
    }

    // 多根节点 → 包裹在 view 容器中
    let mut lines = Vec::new();
    let indent = ctx.indent_str();
    lines.push(format!("{indent}var _root_children = [];"));

    gen_children_into_array("_root_children", children, ctx, &mut lines)?;

    lines.push(format!(
        "{indent}return _h(\"view\", {{}}, {{}}, {{}}, _root_children);"
    ));
    Ok(lines.join("\n"))
}

/// 将子节点生成为 push 到数组的代码。
fn gen_children_into_array(
    array_name: &str,
    children: &[TemplateChild],
    ctx: &mut CodeGenContext,
    lines: &mut Vec<String>,
) -> Result<(), String> {
    let indent = ctx.indent_str();
    let mut i = 0;

    while i < children.len() {
        match &children[i] {
            TemplateChild::Element(node) => {
                // 检查 v-if 链
                let has_if = node.directives.iter().any(|d| d.name == "if");
                if has_if {
                    gen_if_chain(array_name, children, &mut i, ctx, lines)?;
                    continue;
                }

                // 检查 v-for
                let v_for = node.directives.iter().find(|d| d.name == "for");
                if let Some(for_dir) = v_for {
                    gen_for_loop(array_name, node, for_dir, ctx, lines)?;
                    i += 1;
                    continue;
                }

                // 普通元素
                let expr = gen_element(node, ctx)?;
                lines.push(format!("{indent}{array_name}.push({expr});"));
                i += 1;
            }
            TemplateChild::Text(text) => {
                let escaped = escape_js_string(text);
                lines.push(format!(
                    "{indent}{array_name}.push(_h(\"text\", {{content: \"{escaped}\"}}, {{}}, {{}}, []));"
                ));
                i += 1;
            }
            TemplateChild::Interpolation(expr) => {
                lines.push(format!(
                    "{indent}{array_name}.push(_h(\"text\", {{content: String(this.{expr})}}, {{}}, {{}}, []));"
                ));
                i += 1;
            }
            TemplateChild::Comment(_) => {
                i += 1; // 跳过注释
            }
        }
    }

    Ok(())
}

/// 生成元素节点表达式。
fn gen_element(node: &TemplateNode, ctx: &mut CodeGenContext) -> Result<String, String> {
    let tag = &node.tag;

    // 收集 props
    let props = gen_props(node);

    // 收集 style (v-bind:style 或静态 style)
    let style = gen_style(node);

    // 收集 events
    let events = gen_events(node);

    // 生成子节点
    let children_expr = if node.children.is_empty() {
        "[]".to_string()
    } else {
        gen_children_expr(&node.children, ctx)?
    };

    Ok(format!(
        "_h(\"{tag}\", {props}, {style}, {events}, {children_expr})"
    ))
}

/// 生成子节点数组表达式（内联或通过临时变量）。
fn gen_children_expr(
    children: &[TemplateChild],
    ctx: &mut CodeGenContext,
) -> Result<String, String> {
    // 检查是否有动态指令（v-if, v-for），如果有需要生成临时数组
    let has_dynamic = children.iter().any(|c| match c {
        TemplateChild::Element(n) => {
            n.directives
                .iter()
                .any(|d| d.name == "if" || d.name == "for")
        }
        _ => false,
    });

    if has_dynamic {
        // 使用临时数组收集
        let tmp = format!("_c{}", ctx.indent);
        let indent = ctx.indent_str();
        // 这种情况需要在外层生成代码，不适合内联
        // 回退: 生成 IIFE
        let mut inner_lines = Vec::new();
        ctx.indent += 1;
        let inner_indent = ctx.indent_str();
        inner_lines.push(format!("{inner_indent}var {tmp} = [];"));
        gen_children_into_array(&tmp, children, ctx, &mut inner_lines)?;
        inner_lines.push(format!("{inner_indent}return {tmp};"));
        ctx.indent -= 1;

        let body = inner_lines.join("\n");
        Ok(format!("(function() {{\n{body}\n{indent}}}).call(this)"))
    } else {
        // 简单情况: 全部内联
        let mut parts = Vec::new();
        for child in children {
            match child {
                TemplateChild::Element(node) => {
                    let expr = gen_element(node, ctx)?;
                    parts.push(expr);
                }
                TemplateChild::Text(text) => {
                    let escaped = escape_js_string(text);
                    parts.push(format!(
                        "_h(\"text\", {{content: \"{escaped}\"}}, {{}}, {{}}, [])"
                    ));
                }
                TemplateChild::Interpolation(expr) => {
                    parts.push(format!(
                        "_h(\"text\", {{content: String(this.{expr})}}, {{}}, {{}}, [])"
                    ));
                }
                TemplateChild::Comment(_) => {}
            }
        }
        Ok(format!("[{}]", parts.join(", ")))
    }
}

/// 生成 v-if / v-else-if / v-else 链。
fn gen_if_chain(
    array_name: &str,
    children: &[TemplateChild],
    i: &mut usize,
    ctx: &mut CodeGenContext,
    lines: &mut Vec<String>,
) -> Result<(), String> {
    let indent = ctx.indent_str();

    // v-if
    if let TemplateChild::Element(node) = &children[*i] {
        let cond = node
            .directives
            .iter()
            .find(|d| d.name == "if")
            .map(|d| &d.expr)
            .unwrap();
        let expr = gen_element(node, ctx)?;
        lines.push(format!("{indent}if (this.{cond}) {{"));
        ctx.indent += 1;
        lines.push(format!("{}{array_name}.push({expr});", ctx.indent_str()));
        ctx.indent -= 1;
    }
    *i += 1;

    // v-else-if / v-else
    while *i < children.len() {
        if let TemplateChild::Element(node) = &children[*i] {
            let has_else_if = node.directives.iter().find(|d| d.name == "else-if");
            let has_else = node.directives.iter().any(|d| d.name == "else");

            if let Some(dir) = has_else_if {
                let expr = gen_element(node, ctx)?;
                lines.push(format!("{indent}}} else if (this.{}) {{", dir.expr));
                ctx.indent += 1;
                lines.push(format!("{}{array_name}.push({expr});", ctx.indent_str()));
                ctx.indent -= 1;
                *i += 1;
            } else if has_else {
                let expr = gen_element(node, ctx)?;
                lines.push(format!("{indent}}} else {{"));
                ctx.indent += 1;
                lines.push(format!("{}{array_name}.push({expr});", ctx.indent_str()));
                ctx.indent -= 1;
                *i += 1;
                break;
            } else {
                break;
            }
        } else {
            break;
        }
    }

    lines.push(format!("{indent}}}"));
    Ok(())
}

/// 生成 v-for 循环。
fn gen_for_loop(
    array_name: &str,
    node: &TemplateNode,
    for_dir: &Directive,
    ctx: &mut CodeGenContext,
    lines: &mut Vec<String>,
) -> Result<(), String> {
    let indent = ctx.indent_str();

    // 解析 "item in list" 或 "(item, index) in list"
    let expr = &for_dir.expr;
    let (alias, index_alias, source) = parse_for_expr(expr)?;

    let iter_var = format!("_list{}", ctx.indent);
    let idx_var = format!("_i{}", ctx.indent);

    lines.push(format!("{indent}var {iter_var} = this.{source};"));
    lines.push(format!(
        "{indent}for (var {idx_var} = 0; {idx_var} < {iter_var}.length; {idx_var}++) {{"
    ));
    ctx.indent += 1;
    let inner_indent = ctx.indent_str();
    lines.push(format!("{inner_indent}var {alias} = {iter_var}[{idx_var}];"));
    if let Some(idx) = &index_alias {
        lines.push(format!("{inner_indent}var {idx} = {idx_var};"));
    }

    // 生成元素（移除 v-for 指令以避免重复处理）
    let mut node_without_for = node.clone();
    node_without_for
        .directives
        .retain(|d| d.name != "for" && d.name != "bind" || d.arg.as_deref() != Some("key"));

    let elem_expr = gen_element_for_loop(&node_without_for, &alias, ctx)?;
    lines.push(format!("{inner_indent}{array_name}.push({elem_expr});"));

    ctx.indent -= 1;
    lines.push(format!("{indent}}}"));

    Ok(())
}

/// 生成 for 循环内的元素（使用局部变量替代 this.xxx）。
fn gen_element_for_loop(
    node: &TemplateNode,
    _alias: &str,
    ctx: &mut CodeGenContext,
) -> Result<String, String> {
    // 对于 for 循环内的元素，仍然使用 gen_element
    // 但需要注意插值中可能引用循环变量
    gen_element(node, ctx)
}

/// 解析 v-for 表达式。
///
/// - `"item in list"` → ("item", None, "list")
/// - `"(item, index) in list"` → ("item", Some("index"), "list")
fn parse_for_expr(expr: &str) -> Result<(String, Option<String>, String), String> {
    let parts: Vec<&str> = expr.splitn(2, " in ").collect();
    if parts.len() != 2 {
        return Err(format!("Invalid v-for expression: {expr}"));
    }

    let alias_part = parts[0].trim();
    let source = parts[1].trim().to_string();

    if alias_part.starts_with('(') && alias_part.ends_with(')') {
        // (item, index)
        let inner = &alias_part[1..alias_part.len() - 1];
        let aliases: Vec<&str> = inner.split(',').map(|s| s.trim()).collect();
        let item = aliases[0].to_string();
        let index = aliases.get(1).map(|s| s.to_string());
        Ok((item, index, source))
    } else {
        Ok((alias_part.to_string(), None, source))
    }
}

/// 生成 props 对象。
fn gen_props(node: &TemplateNode) -> String {
    let mut parts = Vec::new();

    // 静态属性
    for attr in &node.attrs {
        if attr.name == "style" {
            continue; // style 单独处理
        }
        parts.push(format!(
            "{}: \"{}\"",
            attr.name,
            escape_js_string(&attr.value)
        ));
    }

    // v-bind 动态属性
    for dir in &node.directives {
        if dir.name == "bind" {
            if let Some(arg) = &dir.arg {
                if arg == "style" || arg == "key" {
                    continue; // style 和 key 单独处理
                }
                parts.push(format!("{arg}: this.{}", dir.expr));
            }
        }
    }

    if parts.is_empty() {
        "{}".to_string()
    } else {
        format!("{{{}}}", parts.join(", "))
    }
}

/// 生成 style 对象。
fn gen_style(node: &TemplateNode) -> String {
    // 检查 v-bind:style
    for dir in &node.directives {
        if dir.name == "bind" && dir.arg.as_deref() == Some("style") {
            return format!("this.{}", dir.expr);
        }
    }

    // 静态 style 属性
    for attr in &node.attrs {
        if attr.name == "style" {
            return format!("{{{}}}",  attr.value);
        }
    }

    "{}".to_string()
}

/// 生成 events 对象 — {eventType: "methodName"} 格式。
fn gen_events(node: &TemplateNode) -> String {
    let events: Vec<String> = node
        .directives
        .iter()
        .filter(|d| d.name == "on")
        .filter_map(|d| {
            d.arg.as_ref().map(|arg| {
                format!("{arg}: \"{}\"", d.expr)
            })
        })
        .collect();

    if events.is_empty() {
        "{}".to_string()
    } else {
        format!("{{{}}}", events.join(", "))
    }
}

/// 转义 JS 字符串中的特殊字符。
fn escape_js_string(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compiler::parser::parse;
    use crate::compiler::tokenizer::tokenize;
    use crate::compiler::transform::transform;

    fn compile(input: &str) -> String {
        let tokens = tokenize(input).unwrap();
        let ast = parse(tokens).unwrap();
        let transformed = transform(ast).unwrap();
        generate(&transformed).unwrap()
    }

    #[test]
    fn simple_static_element() {
        let js = compile("<view></view>");
        assert!(js.contains("function render()"));
        assert!(js.contains("_h(\"view\""));
    }

    #[test]
    fn nested_with_text() {
        let js = compile("<view><text>Hello</text></view>");
        assert!(js.contains("_h(\"view\""));
        assert!(js.contains("_h(\"text\""));
        assert!(js.contains("\"Hello\""));
    }

    #[test]
    fn interpolation_generates_this_ref() {
        let js = compile("<text>{{ message }}</text>");
        assert!(js.contains("this.message"));
    }

    #[test]
    fn v_bind_generates_dynamic_prop() {
        let js = compile(r#"<view :class="cls"></view>"#);
        assert!(js.contains("class: this.cls"));
    }

    #[test]
    fn v_on_generates_events_array() {
        let js = compile(r#"<view @tap="handleTap"></view>"#);
        assert!(js.contains("tap: \"handleTap\""));
    }

    #[test]
    fn v_if_generates_conditional() {
        let js = compile(r#"<view><text v-if="show">Visible</text></view>"#);
        assert!(js.contains("if (this.show)"));
    }

    #[test]
    fn v_for_generates_loop() {
        let js = compile(r#"<view><text v-for="item in list">{{ item }}</text></view>"#);
        assert!(js.contains("for (var"));
        assert!(js.contains("this.list"));
    }

    #[test]
    fn parse_for_expression() {
        let (alias, idx, src) = parse_for_expr("item in list").unwrap();
        assert_eq!(alias, "item");
        assert!(idx.is_none());
        assert_eq!(src, "list");

        let (alias, idx, src) = parse_for_expr("(item, index) in items").unwrap();
        assert_eq!(alias, "item");
        assert_eq!(idx, Some("index".to_string()));
        assert_eq!(src, "items");
    }

    #[test]
    fn self_closing_with_attrs() {
        let js = compile(r#"<image src="logo.png" />"#);
        assert!(js.contains("_h(\"image\""));
        assert!(js.contains("src: \"logo.png\""));
    }

    #[test]
    fn full_component_template() {
        let js = compile(r#"
            <view @tap="increment">
                <text>Count: {{ count }}</text>
                <image src="icon.png" />
            </view>
        "#);
        assert!(js.contains("function render()"));
        assert!(js.contains("tap: \"increment\""));
        assert!(js.contains("this.count"));
        assert!(js.contains("src: \"icon.png\""));
    }
}
