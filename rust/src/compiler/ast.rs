//! AST 定义 — 模板解析后的抽象语法树。

/// 模板 AST 根节点。
#[derive(Debug, Clone)]
pub struct TemplateRoot {
    /// 顶层子节点。
    pub children: Vec<TemplateChild>,
}

/// 模板子节点。
#[derive(Debug, Clone)]
pub enum TemplateChild {
    /// 元素节点 (标签)。
    Element(TemplateNode),
    /// 纯文本。
    Text(String),
    /// 插值表达式 `{{ expr }}`。
    Interpolation(String),
    /// 注释。
    Comment(String),
}

/// 元素节点。
#[derive(Debug, Clone)]
pub struct TemplateNode {
    /// 标签名: "view", "text", "image", etc.
    pub tag: String,
    /// 静态属性。
    pub attrs: Vec<Attribute>,
    /// 指令列表: v-if, v-for, v-bind, v-on, v-model, v-show。
    pub directives: Vec<Directive>,
    /// 子节点。
    pub children: Vec<TemplateChild>,
    /// 是否自闭合标签。
    pub is_self_closing: bool,
}

/// 静态属性 (name="value")。
#[derive(Debug, Clone)]
pub struct Attribute {
    pub name: String,
    pub value: String,
}

/// 指令。
#[derive(Debug, Clone)]
pub struct Directive {
    /// 指令名: "if", "else-if", "else", "for", "bind", "on", "model", "show"。
    pub name: String,
    /// 指令参数 (v-bind:prop 中的 "prop", v-on:click 中的 "click")。
    pub arg: Option<String>,
    /// 指令表达式 (v-if="expr" 中的 "expr")。
    pub expr: String,
    /// 修饰符 (v-on:click.prevent 中的 ["prevent"])。
    pub modifiers: Vec<String>,
}
