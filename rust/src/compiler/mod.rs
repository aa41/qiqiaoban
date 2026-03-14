//! Vue 模板编译器模块。
//!
//! 实现 Vue 模板语法 → JS render 函数的编译管线:
//!
//! ```text
//! Template → Tokenizer → Parser → AST → Transform → CodeGen → JS render function
//! ```

pub mod ast;
pub mod codegen;
pub mod parser;
pub mod token;
pub mod tokenizer;
pub mod transform;


/// 编译 Vue 模板为 JS render 函数。
///
/// 完整管线: 模板字符串 → tokenize → parse → transform → codegen。
pub fn compile(template: &str) -> Result<String, String> {
    let tokens = tokenizer::tokenize(template)?;
    let ast = parser::parse(tokens)?;
    let transformed = transform::transform(ast)?;
    let js_code = codegen::generate(&transformed)?;
    Ok(js_code)
}
