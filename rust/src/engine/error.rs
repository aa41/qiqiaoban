//! 统一错误类型，贯穿 JS 引擎层的所有操作。

use std::fmt;

/// JS 引擎操作的统一错误类型。
///
/// 将 rquickjs 内部错误和自定义错误统一为一个可序列化的错误，
/// 方便通过 FFI 传递给 Dart 侧。
#[derive(Debug, Clone)]
pub struct EngineError {
    /// 错误分类。
    pub kind: ErrorKind,
    /// 人类可读的错误消息。
    pub message: String,
}

/// 错误分类枚举。
#[derive(Debug, Clone)]
pub enum ErrorKind {
    /// JS 运行时初始化失败。
    RuntimeInit,
    /// JS 代码执行错误（语法错误、运行时异常等）。
    Eval,
    /// 函数注册失败。
    FunctionRegister,
    /// 类型转换失败（JS ↔ Rust 值转换）。
    TypeConversion,
    /// 引擎已销毁或无效引用。
    InvalidState,
}

impl fmt::Display for EngineError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{:?}] {}", self.kind, self.message)
    }
}

impl std::error::Error for EngineError {}

impl EngineError {
    /// 创建一个运行时初始化错误。
    pub fn runtime_init(msg: impl Into<String>) -> Self {
        Self {
            kind: ErrorKind::RuntimeInit,
            message: msg.into(),
        }
    }

    /// 创建一个 JS 执行错误。
    pub fn eval(msg: impl Into<String>) -> Self {
        Self {
            kind: ErrorKind::Eval,
            message: msg.into(),
        }
    }

    /// 创建一个类型转换错误。
    pub fn type_conversion(msg: impl Into<String>) -> Self {
        Self {
            kind: ErrorKind::TypeConversion,
            message: msg.into(),
        }
    }

    /// 创建一个无效状态错误。
    pub fn invalid_state(msg: impl Into<String>) -> Self {
        Self {
            kind: ErrorKind::InvalidState,
            message: msg.into(),
        }
    }
}

/// 将 rquickjs 的错误转换为 EngineError。
impl From<rquickjs::Error> for EngineError {
    fn from(err: rquickjs::Error) -> Self {
        match &err {
            rquickjs::Error::Exception => Self::eval(format!("JS exception: {err}")),
            _ => Self::eval(format!("QuickJS error: {err}")),
        }
    }
}

/// 便捷的 Result 类型别名。
pub type EngineResult<T> = Result<T, EngineError>;
