//! Token 定义 — 模板 tokenizer 的输出。

/// 模板 Token。
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    /// 开始标签起始: `<tagName`
    TagOpen(String),
    /// 结束标签: `</tagName>`
    TagClose(String),
    /// 自闭合标签结束: `/>`
    SelfClose,
    /// 标签结束: `>`
    TagEnd,
    /// 属性名
    AttrName(String),
    /// 属性值 (= 号后的值)
    AttrValue(String),
    /// 纯文本内容
    Text(String),
    /// 插值表达式: `{{ expr }}`
    Interpolation(String),
    /// HTML 注释: `<!-- ... -->`
    Comment(String),
}
