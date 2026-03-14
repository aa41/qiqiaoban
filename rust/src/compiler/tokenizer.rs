//! 模板 Tokenizer — 状态机将模板字符串转为 Token 流。

use super::token::Token;

/// 将模板字符串 tokenize 为 Token 列表。
pub fn tokenize(template: &str) -> Result<Vec<Token>, String> {
    let mut tokens = Vec::new();
    let chars: Vec<char> = template.chars().collect();
    let len = chars.len();
    let mut i = 0;

    while i < len {
        if chars[i] == '<' {
            // 注释: <!-- ... -->
            if i + 3 < len && chars[i + 1] == '!' && chars[i + 2] == '-' && chars[i + 3] == '-' {
                i += 4; // skip <!--
                let start = i;
                while i + 2 < len && !(chars[i] == '-' && chars[i + 1] == '-' && chars[i + 2] == '>') {
                    i += 1;
                }
                let comment: String = chars[start..i].iter().collect();
                tokens.push(Token::Comment(comment.trim().to_string()));
                if i + 2 < len {
                    i += 3; // skip -->
                }
                continue;
            }

            // 结束标签: </tagName>
            if i + 1 < len && chars[i + 1] == '/' {
                i += 2; // skip </
                skip_whitespace(&chars, &mut i, len);
                let tag = read_tag_name(&chars, &mut i, len);
                skip_whitespace(&chars, &mut i, len);
                if i < len && chars[i] == '>' {
                    i += 1;
                }
                tokens.push(Token::TagClose(tag));
                continue;
            }

            // 开始标签: <tagName
            i += 1; // skip <
            skip_whitespace(&chars, &mut i, len);
            let tag = read_tag_name(&chars, &mut i, len);
            tokens.push(Token::TagOpen(tag));

            // 解析属性
            loop {
                skip_whitespace(&chars, &mut i, len);
                if i >= len {
                    break;
                }

                // 自闭合: />
                if chars[i] == '/' && i + 1 < len && chars[i + 1] == '>' {
                    tokens.push(Token::SelfClose);
                    i += 2;
                    break;
                }

                // 标签结束: >
                if chars[i] == '>' {
                    tokens.push(Token::TagEnd);
                    i += 1;
                    break;
                }

                // 属性名
                let attr_name = read_attr_name(&chars, &mut i, len);
                if attr_name.is_empty() {
                    return Err(format!("Unexpected character '{}' at position {i}", chars[i]));
                }
                tokens.push(Token::AttrName(attr_name));

                skip_whitespace(&chars, &mut i, len);

                // 属性值 (= "value" 或 = 'value' 或 = value)
                if i < len && chars[i] == '=' {
                    i += 1; // skip =
                    skip_whitespace(&chars, &mut i, len);
                    let value = read_attr_value(&chars, &mut i, len);
                    tokens.push(Token::AttrValue(value));
                }
            }
        } else if chars[i] == '{' && i + 1 < len && chars[i + 1] == '{' {
            // 插值: {{ expr }}
            i += 2; // skip {{
            let start = i;
            while i + 1 < len && !(chars[i] == '}' && chars[i + 1] == '}') {
                i += 1;
            }
            let expr: String = chars[start..i].iter().collect();
            tokens.push(Token::Interpolation(expr.trim().to_string()));
            if i + 1 < len {
                i += 2; // skip }}
            }
        } else {
            // 文本内容
            let start = i;
            while i < len && chars[i] != '<' && !(chars[i] == '{' && i + 1 < len && chars[i + 1] == '{') {
                i += 1;
            }
            let text: String = chars[start..i].iter().collect();
            let trimmed = text.trim();
            if !trimmed.is_empty() {
                tokens.push(Token::Text(trimmed.to_string()));
            }
        }
    }

    Ok(tokens)
}

fn skip_whitespace(chars: &[char], i: &mut usize, len: usize) {
    while *i < len && chars[*i].is_whitespace() {
        *i += 1;
    }
}

fn read_tag_name(chars: &[char], i: &mut usize, len: usize) -> String {
    let start = *i;
    while *i < len && (chars[*i].is_alphanumeric() || chars[*i] == '-' || chars[*i] == '_') {
        *i += 1;
    }
    chars[start..*i].iter().collect()
}

fn read_attr_name(chars: &[char], i: &mut usize, len: usize) -> String {
    let start = *i;
    // 属性名可以包含: 字母、数字、-、_、:、.、@、v-
    while *i < len
        && (chars[*i].is_alphanumeric()
            || chars[*i] == '-'
            || chars[*i] == '_'
            || chars[*i] == ':'
            || chars[*i] == '.'
            || chars[*i] == '@')
    {
        *i += 1;
    }
    chars[start..*i].iter().collect()
}

fn read_attr_value(chars: &[char], i: &mut usize, len: usize) -> String {
    if *i >= len {
        return String::new();
    }

    let quote = chars[*i];
    if quote == '"' || quote == '\'' {
        *i += 1; // skip opening quote
        let start = *i;
        while *i < len && chars[*i] != quote {
            *i += 1;
        }
        let value: String = chars[start..*i].iter().collect();
        if *i < len {
            *i += 1; // skip closing quote
        }
        value
    } else {
        // 无引号属性值 (读到空格或 > 或 /)
        let start = *i;
        while *i < len && !chars[*i].is_whitespace() && chars[*i] != '>' && chars[*i] != '/' {
            *i += 1;
        }
        chars[start..*i].iter().collect()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use Token::*;

    #[test]
    fn simple_tag() {
        let tokens = tokenize("<view></view>").unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("view".into()),
                TagEnd,
                TagClose("view".into()),
            ]
        );
    }

    #[test]
    fn nested_tags() {
        let tokens = tokenize("<view><text>Hello</text></view>").unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("view".into()),
                TagEnd,
                TagOpen("text".into()),
                TagEnd,
                Text("Hello".into()),
                TagClose("text".into()),
                TagClose("view".into()),
            ]
        );
    }

    #[test]
    fn self_closing_tag() {
        let tokens = tokenize("<image src=\"url\" />").unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("image".into()),
                AttrName("src".into()),
                AttrValue("url".into()),
                SelfClose,
            ]
        );
    }

    #[test]
    fn attributes_and_directives() {
        let tokens = tokenize(r#"<view v-if="show" :class="cls" @tap="handleTap">"#).unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("view".into()),
                AttrName("v-if".into()),
                AttrValue("show".into()),
                AttrName(":class".into()),
                AttrValue("cls".into()),
                AttrName("@tap".into()),
                AttrValue("handleTap".into()),
                TagEnd,
            ]
        );
    }

    #[test]
    fn interpolation() {
        let tokens = tokenize("<text>{{ message }}</text>").unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("text".into()),
                TagEnd,
                Interpolation("message".into()),
                TagClose("text".into()),
            ]
        );
    }

    #[test]
    fn mixed_text_and_interpolation() {
        let tokens = tokenize("<text>Hello {{ name }}!</text>").unwrap();
        assert_eq!(
            tokens,
            vec![
                TagOpen("text".into()),
                TagEnd,
                Text("Hello".into()),
                Interpolation("name".into()),
                Text("!".into()),
                TagClose("text".into()),
            ]
        );
    }

    #[test]
    fn comment() {
        let tokens = tokenize("<!-- a comment --><view></view>").unwrap();
        assert_eq!(
            tokens,
            vec![
                Comment("a comment".into()),
                TagOpen("view".into()),
                TagEnd,
                TagClose("view".into()),
            ]
        );
    }
}
