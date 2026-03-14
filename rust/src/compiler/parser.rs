//! 模板 Parser — Token 流 → AST 树。

use super::ast::*;
use super::token::Token;

/// 将 Token 列表解析为 AST。
pub fn parse(tokens: Vec<Token>) -> Result<TemplateRoot, String> {
    let mut parser = Parser::new(tokens);
    let children = parser.parse_children()?;
    Ok(TemplateRoot { children })
}

struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

impl Parser {
    fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn advance(&mut self) -> Option<&Token> {
        let tok = self.tokens.get(self.pos);
        if tok.is_some() {
            self.pos += 1;
        }
        tok
    }

    fn expect(&mut self, expected: &str) -> Result<(), String> {
        if self.pos >= self.tokens.len() {
            return Err(format!("Unexpected end of tokens, expected {expected}"));
        }
        Ok(())
    }

    /// 解析子节点列表，直到遇到结束标签或 token 流结束。
    fn parse_children(&mut self) -> Result<Vec<TemplateChild>, String> {
        let mut children = Vec::new();

        while let Some(tok) = self.peek() {
            match tok {
                Token::TagClose(_) => break, // 父节点的结束标签
                Token::TagOpen(_) => {
                    let node = self.parse_element()?;
                    children.push(TemplateChild::Element(node));
                }
                Token::Text(_) => {
                    if let Some(Token::Text(text)) = self.advance() {
                        let text = text.clone();
                        children.push(TemplateChild::Text(text));
                    }
                }
                Token::Interpolation(_) => {
                    if let Some(Token::Interpolation(expr)) = self.advance() {
                        let expr = expr.clone();
                        children.push(TemplateChild::Interpolation(expr));
                    }
                }
                Token::Comment(_) => {
                    if let Some(Token::Comment(text)) = self.advance() {
                        let text = text.clone();
                        children.push(TemplateChild::Comment(text));
                    }
                }
                _ => {
                    // 跳过意外的 token
                    self.advance();
                }
            }
        }

        Ok(children)
    }

    /// 解析元素节点。
    fn parse_element(&mut self) -> Result<TemplateNode, String> {
        // 消费 TagOpen
        let tag = match self.advance() {
            Some(Token::TagOpen(name)) => name.clone(),
            other => return Err(format!("Expected TagOpen, got {other:?}")),
        };

        // 解析属性和指令
        let mut attrs = Vec::new();
        let mut directives = Vec::new();
        let mut is_self_closing = false;

        loop {
            match self.peek() {
                Some(Token::SelfClose) => {
                    self.advance();
                    is_self_closing = true;
                    break;
                }
                Some(Token::TagEnd) => {
                    self.advance();
                    break;
                }
                Some(Token::AttrName(_)) => {
                    let name = match self.advance() {
                        Some(Token::AttrName(n)) => n.clone(),
                        _ => unreachable!(),
                    };

                    // 检查是否有值
                    let value = if matches!(self.peek(), Some(Token::AttrValue(_))) {
                        match self.advance() {
                            Some(Token::AttrValue(v)) => v.clone(),
                            _ => unreachable!(),
                        }
                    } else {
                        String::new()
                    };

                    // 分类: 指令 vs 静态属性
                    if let Some(dir) = parse_directive(&name, &value) {
                        directives.push(dir);
                    } else {
                        attrs.push(Attribute { name, value });
                    }
                }
                None => return Err(format!("Unexpected end of tokens in tag <{tag}>")),
                _ => {
                    self.advance(); // 跳过未知 token
                }
            }
        }

        // 解析子节点 (非自闭合标签)
        let children = if is_self_closing {
            Vec::new()
        } else {
            let children = self.parse_children()?;

            // 消费结束标签 </tag>
            match self.peek() {
                Some(Token::TagClose(close_tag)) if close_tag == &tag => {
                    self.advance();
                }
                Some(Token::TagClose(close_tag)) => {
                    return Err(format!(
                        "Mismatched closing tag: expected </{tag}>, got </{close_tag}>"
                    ));
                }
                _ => {
                    return Err(format!("Missing closing tag for <{tag}>"));
                }
            }

            children
        };

        Ok(TemplateNode {
            tag,
            attrs,
            directives,
            children,
            is_self_closing,
        })
    }
}

/// 解析属性名为指令 (如果是的话)。
///
/// 识别模式:
/// - `v-if`, `v-else-if`, `v-else`, `v-for`, `v-show`, `v-model`
/// - `v-bind:prop` 或 `:prop`
/// - `v-on:event` 或 `@event`
/// - `v-on:event.modifier`
fn parse_directive(name: &str, value: &str) -> Option<Directive> {
    if name.starts_with("v-") {
        let rest = &name[2..];

        // v-bind:prop
        if let Some(arg) = rest.strip_prefix("bind:") {
            let (arg, modifiers) = parse_arg_modifiers(arg);
            return Some(Directive {
                name: "bind".to_string(),
                arg: Some(arg),
                expr: value.to_string(),
                modifiers,
            });
        }

        // v-on:event
        if let Some(arg) = rest.strip_prefix("on:") {
            let (arg, modifiers) = parse_arg_modifiers(arg);
            return Some(Directive {
                name: "on".to_string(),
                arg: Some(arg),
                expr: value.to_string(),
                modifiers,
            });
        }

        // v-if, v-else-if, v-else, v-for, v-show, v-model
        let (dir_name, modifiers) = parse_arg_modifiers(rest);
        Some(Directive {
            name: dir_name,
            arg: None,
            expr: value.to_string(),
            modifiers,
        })
    } else if name.starts_with(':') {
        // :prop → v-bind:prop
        let arg = &name[1..];
        let (arg, modifiers) = parse_arg_modifiers(arg);
        Some(Directive {
            name: "bind".to_string(),
            arg: Some(arg),
            expr: value.to_string(),
            modifiers,
        })
    } else if name.starts_with('@') {
        // @event → v-on:event
        let arg = &name[1..];
        let (arg, modifiers) = parse_arg_modifiers(arg);
        Some(Directive {
            name: "on".to_string(),
            arg: Some(arg),
            expr: value.to_string(),
            modifiers,
        })
    } else {
        None
    }
}

/// 解析参数和修饰符: "click.prevent.stop" → ("click", ["prevent", "stop"])
fn parse_arg_modifiers(s: &str) -> (String, Vec<String>) {
    let parts: Vec<&str> = s.split('.').collect();
    let arg = parts[0].to_string();
    let modifiers = parts[1..].iter().map(|s| s.to_string()).collect();
    (arg, modifiers)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compiler::tokenizer::tokenize;

    #[test]
    fn parse_simple_element() {
        let tokens = tokenize("<view></view>").unwrap();
        let root = parse(tokens).unwrap();
        assert_eq!(root.children.len(), 1);
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.tag, "view");
            assert!(node.children.is_empty());
        } else {
            panic!("Expected Element");
        }
    }

    #[test]
    fn parse_nested_with_text() {
        let tokens = tokenize("<view><text>Hello</text></view>").unwrap();
        let root = parse(tokens).unwrap();
        assert_eq!(root.children.len(), 1);
        if let TemplateChild::Element(view) = &root.children[0] {
            assert_eq!(view.tag, "view");
            assert_eq!(view.children.len(), 1);
            if let TemplateChild::Element(text) = &view.children[0] {
                assert_eq!(text.tag, "text");
                assert_eq!(text.children.len(), 1);
                assert!(matches!(&text.children[0], TemplateChild::Text(t) if t == "Hello"));
            } else {
                panic!("Expected text element");
            }
        } else {
            panic!("Expected view element");
        }
    }

    #[test]
    fn parse_self_closing() {
        let tokens = tokenize(r#"<image src="url" />"#).unwrap();
        let root = parse(tokens).unwrap();
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.tag, "image");
            assert!(node.is_self_closing);
            assert_eq!(node.attrs.len(), 1);
            assert_eq!(node.attrs[0].name, "src");
            assert_eq!(node.attrs[0].value, "url");
        } else {
            panic!("Expected Element");
        }
    }

    #[test]
    fn parse_directives() {
        let tokens =
            tokenize(r#"<view v-if="show" :class="cls" @tap="handleTap"></view>"#).unwrap();
        let root = parse(tokens).unwrap();
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.directives.len(), 3);

            assert_eq!(node.directives[0].name, "if");
            assert_eq!(node.directives[0].expr, "show");

            assert_eq!(node.directives[1].name, "bind");
            assert_eq!(node.directives[1].arg.as_deref(), Some("class"));
            assert_eq!(node.directives[1].expr, "cls");

            assert_eq!(node.directives[2].name, "on");
            assert_eq!(node.directives[2].arg.as_deref(), Some("tap"));
            assert_eq!(node.directives[2].expr, "handleTap");
        } else {
            panic!("Expected Element");
        }
    }

    #[test]
    fn parse_interpolation() {
        let tokens = tokenize("<text>{{ message }}</text>").unwrap();
        let root = parse(tokens).unwrap();
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.children.len(), 1);
            assert!(
                matches!(&node.children[0], TemplateChild::Interpolation(e) if e == "message")
            );
        } else {
            panic!("Expected Element");
        }
    }

    #[test]
    fn parse_v_for() {
        let tokens =
            tokenize(r#"<view v-for="item in list" :key="item.id"></view>"#).unwrap();
        let root = parse(tokens).unwrap();
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.directives.len(), 2);
            assert_eq!(node.directives[0].name, "for");
            assert_eq!(node.directives[0].expr, "item in list");
            assert_eq!(node.directives[1].name, "bind");
            assert_eq!(node.directives[1].arg.as_deref(), Some("key"));
        } else {
            panic!("Expected Element");
        }
    }

    #[test]
    fn parse_event_modifiers() {
        let tokens =
            tokenize(r#"<button @tap.prevent.stop="handleClick"></button>"#).unwrap();
        let root = parse(tokens).unwrap();
        if let TemplateChild::Element(node) = &root.children[0] {
            assert_eq!(node.directives[0].name, "on");
            assert_eq!(node.directives[0].arg.as_deref(), Some("tap"));
            assert_eq!(node.directives[0].modifiers, vec!["prevent", "stop"]);
        } else {
            panic!("Expected Element");
        }
    }
}
