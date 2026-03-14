//! 性能基准测试 — 编译器和渲染管线。
//!
//! 运行: `cargo test bench_ -- --nocapture`

#[cfg(test)]
mod bench_tests {
    use crate::compiler;
    use crate::vnode::diff;
    use crate::vnode::layout_bridge;
    use crate::vnode::node::{PropValue, VNode, VNodeType};
    use std::collections::HashMap;
    use std::time::Instant;

    fn make_vnode(n_children: usize, prefix: &str) -> VNode {
        let children: Vec<VNode> = (0..n_children)
            .map(|i| VNode {
                id: (i + 100) as u32,
                node_type: VNodeType::Text,
                props: [("content".to_string(), PropValue::Str(format!("{prefix}-{i}")))]
                    .into_iter()
                    .collect(),
                style: Default::default(),
                events: HashMap::new(),
                children: vec![],
            })
            .collect();

        VNode {
            id: 1,
            node_type: VNodeType::View,
            props: Default::default(),
            style: Default::default(),
            events: HashMap::new(),
            children,
        }
    }

    #[test]
    fn bench_compile_simple() {
        let template = "<view><text>Hello</text></view>";
        let n = 1000;
        let start = Instant::now();
        for _ in 0..n {
            compiler::compile(template).unwrap();
        }
        let elapsed = start.elapsed();
        println!(
            "bench_compile_simple: {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_compile_medium() {
        let template = r#"<view><text v-if="show">{{ title }}</text><view v-for="item in items"><text :class="item.cls">{{ item.name }}</text></view><view @tap="click"><text>Go</text></view></view>"#;
        let n = 500;
        let start = Instant::now();
        for _ in 0..n {
            compiler::compile(template).unwrap();
        }
        let elapsed = start.elapsed();
        println!(
            "bench_compile_medium: {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_compile_complex() {
        let mut template = String::from("<view>");
        for i in 0..20 {
            template.push_str(&format!(
                r#"<view v-if="s{i}"><text>{{ t{i} }}</text></view>"#
            ));
        }
        template.push_str("</view>");
        let n = 200;
        let start = Instant::now();
        for _ in 0..n {
            compiler::compile(&template).unwrap();
        }
        let elapsed = start.elapsed();
        println!(
            "bench_compile_complex(20): {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_diff_identical_10() {
        let vnode = make_vnode(10, "a");
        let n = 5000;
        let start = Instant::now();
        for _ in 0..n {
            let _ = diff::diff(&vnode, &vnode);
        }
        let elapsed = start.elapsed();
        println!(
            "bench_diff_identical(10): {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_diff_changed_50() {
        let old = make_vnode(50, "old");
        let new_v = make_vnode(50, "new");
        let n = 2000;
        let start = Instant::now();
        for _ in 0..n {
            let _ = diff::diff(&old, &new_v);
        }
        let elapsed = start.elapsed();
        println!(
            "bench_diff_changed(50): {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_layout_10() {
        let vnode = make_vnode(10, "a");
        let n = 2000;
        let start = Instant::now();
        for _ in 0..n {
            let _ = layout_bridge::compute_vnode_layout(&vnode, 375.0, 812.0);
        }
        let elapsed = start.elapsed();
        println!(
            "bench_layout(10): {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_layout_50() {
        let vnode = make_vnode(50, "a");
        let n = 500;
        let start = Instant::now();
        for _ in 0..n {
            let _ = layout_bridge::compute_vnode_layout(&vnode, 375.0, 812.0);
        }
        let elapsed = start.elapsed();
        println!(
            "bench_layout(50): {n} iters in {:?} ({:.1}μs/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64
        );
    }

    #[test]
    fn bench_full_pipeline() {
        let template = r#"<view @tap="h"><text>{{ title }}</text><text v-if="s">Sub</text><view v-for="i in list"><text>{{ i }}</text></view></view>"#;
        let n = 200;
        let start = Instant::now();
        for _ in 0..n {
            let _js = compiler::compile(template).unwrap();
        }
        let elapsed = start.elapsed();
        println!(
            "bench_full_pipeline: {n} iters in {:?} ({:.1}μs/iter, {:.2}ms/iter)",
            elapsed,
            elapsed.as_micros() as f64 / n as f64,
            elapsed.as_millis() as f64 / n as f64
        );
    }
}
