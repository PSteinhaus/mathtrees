#[macro_export]
macro_rules! time_it {
    ($name:expr, $expr:expr) => {{
        let start = std::time::Instant::now();
        let result = $expr;
        let elapsed = start.elapsed();

        godot_print!("{} took {:?}", $name, elapsed);

        result
    }};
}