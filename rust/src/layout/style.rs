//! Flex 样式定义 — CSS Flexbox 属性到 Taffy Style 的映射。
//!
//! 定义了一套精简的 Flex 样式 API，对应 Vue 模板中可使用的样式属性子集。
//! 不支持完整 CSS，仅覆盖 Flexbox 布局所需的核心属性。

use taffy::prelude::*;

/// 七巧板节点样式 — Flexbox 属性映射。
///
/// 对应 Vue 模板中的样式属性子集：
///
/// ```html
/// <view style="
///   display: flex;
///   flex-direction: row;
///   justify-content: center;
///   align-items: stretch;
///   width: 100px;
///   height: 50px;
///   padding: 8px;
///   margin: 4px;
///   gap: 10px;
///   flex-grow: 1;
///   flex-shrink: 0;
/// ">
/// ```
#[derive(Debug, Clone)]
pub struct QBStyle {
    // --- 布局模式 ---
    pub display: QBDisplay,
    pub position: QBPosition,

    // --- Flex 容器属性 ---
    pub flex_direction: QBFlexDirection,
    pub flex_wrap: QBFlexWrap,
    pub justify_content: QBJustifyContent,
    pub align_items: QBAlignItems,
    pub align_content: QBAlignContent,
    pub gap_row: f32,
    pub gap_column: f32,

    // --- Flex 子项属性 ---
    pub flex_grow: f32,
    pub flex_shrink: f32,
    pub flex_basis: QBDimension,
    pub align_self: QBAlignSelf,

    // --- 尺寸 ---
    pub width: QBDimension,
    pub height: QBDimension,
    pub min_width: QBDimension,
    pub min_height: QBDimension,
    pub max_width: QBDimension,
    pub max_height: QBDimension,

    // --- 间距 ---
    pub padding_top: f32,
    pub padding_right: f32,
    pub padding_bottom: f32,
    pub padding_left: f32,
    pub margin_top: QBLengthPercentageAuto,
    pub margin_right: QBLengthPercentageAuto,
    pub margin_bottom: QBLengthPercentageAuto,
    pub margin_left: QBLengthPercentageAuto,

    // --- 定位偏移 (仅 position: absolute 生效) ---
    pub inset_top: QBLengthPercentageAuto,
    pub inset_right: QBLengthPercentageAuto,
    pub inset_bottom: QBLengthPercentageAuto,
    pub inset_left: QBLengthPercentageAuto,

    // --- 溢出控制 (scroll-view 用) ---
    pub overflow_x: QBOverflow,
    pub overflow_y: QBOverflow,
}

impl Default for QBStyle {
    fn default() -> Self {
        Self {
            display: QBDisplay::Flex,
            position: QBPosition::Relative,
            flex_direction: QBFlexDirection::Row,
            flex_wrap: QBFlexWrap::NoWrap,
            justify_content: QBJustifyContent::FlexStart,
            align_items: QBAlignItems::Stretch,
            align_content: QBAlignContent::Stretch,
            gap_row: 0.0,
            gap_column: 0.0,
            flex_grow: 0.0,
            flex_shrink: 1.0,
            flex_basis: QBDimension::Auto,
            align_self: QBAlignSelf::Auto,
            width: QBDimension::Auto,
            height: QBDimension::Auto,
            min_width: QBDimension::Auto,
            min_height: QBDimension::Auto,
            max_width: QBDimension::Auto,
            max_height: QBDimension::Auto,
            padding_top: 0.0,
            padding_right: 0.0,
            padding_bottom: 0.0,
            padding_left: 0.0,
            margin_top: QBLengthPercentageAuto::Length(0.0),
            margin_right: QBLengthPercentageAuto::Length(0.0),
            margin_bottom: QBLengthPercentageAuto::Length(0.0),
            margin_left: QBLengthPercentageAuto::Length(0.0),
            inset_top: QBLengthPercentageAuto::Auto,
            inset_right: QBLengthPercentageAuto::Auto,
            inset_bottom: QBLengthPercentageAuto::Auto,
            inset_left: QBLengthPercentageAuto::Auto,
            overflow_x: QBOverflow::Visible,
            overflow_y: QBOverflow::Visible,
        }
    }
}

// ---------------------------------------------------------------------------
// 枚举定义 — 与 CSS 属性值一一对应
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, Default)]
pub enum QBDisplay {
    #[default]
    Flex,
    None,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBPosition {
    #[default]
    Relative,
    Absolute,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBFlexDirection {
    #[default]
    Row,
    Column,
    RowReverse,
    ColumnReverse,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBFlexWrap {
    #[default]
    NoWrap,
    Wrap,
    WrapReverse,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBJustifyContent {
    #[default]
    FlexStart,
    FlexEnd,
    Center,
    SpaceBetween,
    SpaceAround,
    SpaceEvenly,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBAlignItems {
    FlexStart,
    FlexEnd,
    Center,
    #[default]
    Stretch,
    Baseline,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBAlignContent {
    FlexStart,
    FlexEnd,
    Center,
    #[default]
    Stretch,
    SpaceBetween,
    SpaceAround,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBAlignSelf {
    #[default]
    Auto,
    FlexStart,
    FlexEnd,
    Center,
    Stretch,
    Baseline,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum QBOverflow {
    #[default]
    Visible,
    Hidden,
    Scroll,
}

#[derive(Debug, Clone, Copy)]
pub enum QBDimension {
    Auto,
    Length(f32),
    Percent(f32),
}

impl Default for QBDimension {
    fn default() -> Self {
        Self::Auto
    }
}

#[derive(Debug, Clone, Copy)]
pub enum QBLengthPercentageAuto {
    Auto,
    Length(f32),
    Percent(f32),
}

impl Default for QBLengthPercentageAuto {
    fn default() -> Self {
        Self::Auto
    }
}

// ---------------------------------------------------------------------------
// QBStyle → Taffy Style 转换
// ---------------------------------------------------------------------------

impl QBStyle {
    /// 将七巧板样式转换为 Taffy 内部样式。
    pub fn to_taffy_style(&self) -> Style {
        Style {
            display: match self.display {
                QBDisplay::Flex => Display::Flex,
                QBDisplay::None => Display::None,
            },
            position: match self.position {
                QBPosition::Relative => Position::Relative,
                QBPosition::Absolute => Position::Absolute,
            },
            flex_direction: match self.flex_direction {
                QBFlexDirection::Row => FlexDirection::Row,
                QBFlexDirection::Column => FlexDirection::Column,
                QBFlexDirection::RowReverse => FlexDirection::RowReverse,
                QBFlexDirection::ColumnReverse => FlexDirection::ColumnReverse,
            },
            flex_wrap: match self.flex_wrap {
                QBFlexWrap::NoWrap => FlexWrap::NoWrap,
                QBFlexWrap::Wrap => FlexWrap::Wrap,
                QBFlexWrap::WrapReverse => FlexWrap::WrapReverse,
            },
            justify_content: Some(match self.justify_content {
                QBJustifyContent::FlexStart => JustifyContent::FlexStart,
                QBJustifyContent::FlexEnd => JustifyContent::FlexEnd,
                QBJustifyContent::Center => JustifyContent::Center,
                QBJustifyContent::SpaceBetween => JustifyContent::SpaceBetween,
                QBJustifyContent::SpaceAround => JustifyContent::SpaceAround,
                QBJustifyContent::SpaceEvenly => JustifyContent::SpaceEvenly,
            }),
            align_items: Some(match self.align_items {
                QBAlignItems::FlexStart => AlignItems::FlexStart,
                QBAlignItems::FlexEnd => AlignItems::FlexEnd,
                QBAlignItems::Center => AlignItems::Center,
                QBAlignItems::Stretch => AlignItems::Stretch,
                QBAlignItems::Baseline => AlignItems::Baseline,
            }),
            align_content: Some(match self.align_content {
                QBAlignContent::FlexStart => AlignContent::FlexStart,
                QBAlignContent::FlexEnd => AlignContent::FlexEnd,
                QBAlignContent::Center => AlignContent::Center,
                QBAlignContent::Stretch => AlignContent::Stretch,
                QBAlignContent::SpaceBetween => AlignContent::SpaceBetween,
                QBAlignContent::SpaceAround => AlignContent::SpaceAround,
            }),
            gap: Size {
                width: length(self.gap_column),
                height: length(self.gap_row),
            },
            flex_grow: self.flex_grow,
            flex_shrink: self.flex_shrink,
            flex_basis: to_taffy_dimension(self.flex_basis),
            align_self: match self.align_self {
                QBAlignSelf::Auto => None,
                QBAlignSelf::FlexStart => Some(AlignSelf::FlexStart),
                QBAlignSelf::FlexEnd => Some(AlignSelf::FlexEnd),
                QBAlignSelf::Center => Some(AlignSelf::Center),
                QBAlignSelf::Stretch => Some(AlignSelf::Stretch),
                QBAlignSelf::Baseline => Some(AlignSelf::Baseline),
            },
            size: Size {
                width: to_taffy_dimension(self.width),
                height: to_taffy_dimension(self.height),
            },
            min_size: Size {
                width: to_taffy_dimension(self.min_width),
                height: to_taffy_dimension(self.min_height),
            },
            max_size: Size {
                width: to_taffy_dimension(self.max_width),
                height: to_taffy_dimension(self.max_height),
            },
            padding: Rect {
                top: length(self.padding_top),
                right: length(self.padding_right),
                bottom: length(self.padding_bottom),
                left: length(self.padding_left),
            },
            margin: Rect {
                top: to_taffy_lpa(self.margin_top),
                right: to_taffy_lpa(self.margin_right),
                bottom: to_taffy_lpa(self.margin_bottom),
                left: to_taffy_lpa(self.margin_left),
            },
            inset: Rect {
                top: to_taffy_lpa(self.inset_top),
                right: to_taffy_lpa(self.inset_right),
                bottom: to_taffy_lpa(self.inset_bottom),
                left: to_taffy_lpa(self.inset_left),
            },
            overflow: taffy::Point {
                x: match self.overflow_x {
                    QBOverflow::Visible => taffy::Overflow::Visible,
                    QBOverflow::Hidden => taffy::Overflow::Hidden,
                    QBOverflow::Scroll => taffy::Overflow::Scroll,
                },
                y: match self.overflow_y {
                    QBOverflow::Visible => taffy::Overflow::Visible,
                    QBOverflow::Hidden => taffy::Overflow::Hidden,
                    QBOverflow::Scroll => taffy::Overflow::Scroll,
                },
            },
            ..Style::DEFAULT
        }
    }
}

// ---------------------------------------------------------------------------
// 转换辅助函数
// ---------------------------------------------------------------------------

fn to_taffy_dimension(dim: QBDimension) -> Dimension {
    match dim {
        QBDimension::Auto => Dimension::Auto,
        QBDimension::Length(v) => Dimension::Length(v),
        QBDimension::Percent(v) => Dimension::Percent(v / 100.0),
    }
}

fn to_taffy_lpa(lpa: QBLengthPercentageAuto) -> LengthPercentageAuto {
    match lpa {
        QBLengthPercentageAuto::Auto => LengthPercentageAuto::Auto,
        QBLengthPercentageAuto::Length(v) => LengthPercentageAuto::Length(v),
        QBLengthPercentageAuto::Percent(v) => LengthPercentageAuto::Percent(v / 100.0),
    }
}
