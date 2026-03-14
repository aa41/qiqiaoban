//! 指令转换 — AST 语义检查与增强。
//!
//! 验证指令正确性:
//! - `v-else-if` / `v-else` 必须紧跟 `v-if` 或 `v-else-if`
//! - `v-for` 必须有表达式
//! - `v-model` 仅用于 input 元素

use super::ast::*;

/// 对 AST 执行指令转换和验证。
pub fn transform(mut root: TemplateRoot) -> Result<TemplateRoot, String> {
    transform_children(&mut root.children)?;
    Ok(root)
}

fn transform_children(children: &mut Vec<TemplateChild>) -> Result<(), String> {
    // 验证 v-if / v-else-if / v-else 链
    let mut last_had_if = false;

    for child in children.iter_mut() {
        match child {
            TemplateChild::Element(node) => {
                let has_if = node.directives.iter().any(|d| d.name == "if");
                let has_else_if = node.directives.iter().any(|d| d.name == "else-if");
                let has_else = node
                    .directives
                    .iter()
                    .any(|d| d.name == "else");

                if (has_else_if || has_else) && !last_had_if {
                    return Err(format!(
                        "<{}> has v-else-if/v-else without a preceding v-if",
                        node.tag
                    ));
                }

                last_had_if = has_if || has_else_if;

                // 验证 v-for
                for dir in &node.directives {
                    if dir.name == "for" && dir.expr.is_empty() {
                        return Err(format!("<{}> v-for requires an expression", node.tag));
                    }
                    if dir.name == "model" && node.tag != "input" && node.tag != "textarea" {
                        return Err(format!(
                            "v-model is only valid on <input> and <textarea>, found on <{}>",
                            node.tag
                        ));
                    }
                }

                // 递归转换子节点
                transform_children(&mut node.children)?;
            }
            _ => {
                last_had_if = false;
            }
        }
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compiler::parser::parse;
    use crate::compiler::tokenizer::tokenize;

    fn parse_template(input: &str) -> TemplateRoot {
        let tokens = tokenize(input).unwrap();
        parse(tokens).unwrap()
    }

    #[test]
    fn valid_if_else_chain() {
        let root = parse_template(
            r#"<view v-if="a"></view><view v-else-if="b"></view><view v-else></view>"#,
        );
        assert!(transform(root).is_ok());
    }

    #[test]
    fn else_without_if_fails() {
        let root = parse_template(r#"<view v-else></view>"#);
        assert!(transform(root).is_err());
    }

    #[test]
    fn else_if_without_if_fails() {
        let root = parse_template(r#"<view v-else-if="b"></view>"#);
        assert!(transform(root).is_err());
    }

    #[test]
    fn v_model_on_non_input_fails() {
        let root = parse_template(r#"<view v-model="text"></view>"#);
        assert!(transform(root).is_err());
    }

    #[test]
    fn v_model_on_input_ok() {
        let root = parse_template(r#"<input v-model="text" />"#);
        assert!(transform(root).is_ok());
    }

    #[test]
    fn v_for_empty_expr_fails() {
        // Manually construct since tokenizer won't produce empty v-for expr easily
        let root = TemplateRoot {
            children: vec![TemplateChild::Element(TemplateNode {
                tag: "view".to_string(),
                attrs: vec![],
                directives: vec![Directive {
                    name: "for".to_string(),
                    arg: None,
                    expr: String::new(),
                    modifiers: vec![],
                }],
                children: vec![],
                is_self_closing: false,
            })],
        };
        assert!(transform(root).is_err());
    }
}
