; ============================================================================
; LastStack Demo: Fractal Generator (LLVM IR, no C source)
; ============================================================================
;
; Exports expected by the client:
;   - generate_fractal(width, height, max_iter) -> i32 pointer to RGBA buffer
;   - get_buffer() -> i32 pointer to buffer
;   - get_buffer_size() -> i32 bytes valid in buffer
;   - free_buffer(ptr) -> void (no-op for static buffer)
;
; Internal helpers:
;   - map(...) -> linear mapping utility
;   - mandelbrot_iter(...) -> per-pixel iteration count
;
; ============================================================================

target triple = "wasm32-unknown-unknown"

@pixel_buffer = internal global [16777216 x i8] zeroinitializer, align 16
@buffer_ptr = global i32 0, align 4
@buffer_size = global i32 0, align 4

; ============================================================================
; map(value, in_min, in_max, out_min, out_max)
; ============================================================================
define i32 @map(i32 %value, i32 %in_min, i32 %in_max, i32 %out_min, i32 %out_max) {
entry:
  %in_range = sub i32 %in_max, %in_min
  %range_zero = icmp eq i32 %in_range, 0
  br i1 %range_zero, label %ret_min, label %calc

ret_min:
  ret i32 %out_min

calc:
  %value_off = sub i32 %value, %in_min
  %out_range = sub i32 %out_max, %out_min
  %scaled = mul i32 %value_off, %out_range
  %div = sdiv i32 %scaled, %in_range
  %result = add i32 %out_min, %div
  ret i32 %result
}

; ============================================================================
; mandelbrot_iter(x, y, width, height, max_iter)
; Fixed-point domain:
;   cx in [-2500, 1000]
;   cy in [-1500, 1500]
; ============================================================================
define i32 @mandelbrot_iter(i32 %x, i32 %y, i32 %width, i32 %height, i32 %max_iter) {
entry:
  %cx = call i32 @map(i32 %x, i32 0, i32 %width, i32 -2500, i32 1000)
  %cy = call i32 @map(i32 %y, i32 0, i32 %height, i32 -1500, i32 1500)
  br label %iter_loop

iter_loop:
  %zx = phi i32 [ 0, %entry ], [ %new_zx, %iter_continue ]
  %zy = phi i32 [ 0, %entry ], [ %new_zy, %iter_continue ]
  %iter = phi i32 [ 0, %entry ], [ %iter_next, %iter_continue ]

  %iter_done = icmp sge i32 %iter, %max_iter
  br i1 %iter_done, label %iter_exit, label %check_escape

check_escape:
  %zx2_raw = mul i32 %zx, %zx
  %zy2_raw = mul i32 %zy, %zy
  %zx2 = sdiv i32 %zx2_raw, 1000
  %zy2 = sdiv i32 %zy2_raw, 1000
  %mag = add i32 %zx2, %zy2
  %escaped = icmp sgt i32 %mag, 4000
  br i1 %escaped, label %iter_exit, label %iter_continue

iter_continue:
  %zxzy_raw = mul i32 %zx, %zy
  %two_zxzy = sdiv i32 %zxzy_raw, 500
  %zx_part = sub i32 %zx2, %zy2
  %new_zx = add i32 %zx_part, %cx
  %new_zy = add i32 %two_zxzy, %cy
  %iter_next = add i32 %iter, 1
  br label %iter_loop

iter_exit:
  ret i32 %iter
}

; ============================================================================
; generate_fractal(width, height, max_iter) -> ptr
; Writes RGBA pixels into static @pixel_buffer and returns i32 pointer.
; ============================================================================
define i32 @generate_fractal(i32 %width, i32 %height, i32 %max_iter) {
entry:
  %w_ok = icmp sgt i32 %width, 0
  %h_ok = icmp sgt i32 %height, 0
  %m_ok = icmp sgt i32 %max_iter, 0
  %wh_ok = and i1 %w_ok, %h_ok
  %all_ok = and i1 %wh_ok, %m_ok
  br i1 %all_ok, label %prepare, label %invalid

invalid:
  store i32 0, i32* @buffer_ptr, align 4
  store i32 0, i32* @buffer_size, align 4
  ret i32 0

prepare:
  %w64 = sext i32 %width to i64
  %h64 = sext i32 %height to i64
  %pixels64 = mul i64 %w64, %h64
  %bytes64 = shl i64 %pixels64, 2
  %too_large = icmp sgt i64 %bytes64, 16777216
  %safe_bytes64 = select i1 %too_large, i64 16777216, i64 %bytes64
  %safe_pixels64 = lshr i64 %safe_bytes64, 2
  %safe_bytes32 = trunc i64 %safe_bytes64 to i32
  %safe_pixels32 = trunc i64 %safe_pixels64 to i32

  %buf_ptr = getelementptr [16777216 x i8], [16777216 x i8]* @pixel_buffer, i64 0, i64 0
  %buf_i32 = ptrtoint i8* %buf_ptr to i32
  store i32 %buf_i32, i32* @buffer_ptr, align 4
  store i32 %safe_bytes32, i32* @buffer_size, align 4
  br label %pixel_loop

pixel_loop:
  %i = phi i32 [ 0, %prepare ], [ %i_next, %pixel_latch ]
  %cont = icmp slt i32 %i, %safe_pixels32
  br i1 %cont, label %pixel_body, label %done

pixel_body:
  %x = srem i32 %i, %width
  %y = sdiv i32 %i, %width
  %iter = call i32 @mandelbrot_iter(i32 %x, i32 %y, i32 %width, i32 %height, i32 %max_iter)

  ; Convert iter -> color in [0,255].
  %iter255 = mul i32 %iter, 255
  %r32 = sdiv i32 %iter255, %max_iter
  %r = and i32 %r32, 255
  %g_mul = mul i32 %r, 5
  %g = and i32 %g_mul, 255
  %b = sub i32 255, %r

  %i64 = sext i32 %i to i64
  %off = shl i64 %i64, 2
  %p0 = getelementptr i8, i8* %buf_ptr, i64 %off
  %p1 = getelementptr i8, i8* %p0, i64 1
  %p2 = getelementptr i8, i8* %p0, i64 2
  %p3 = getelementptr i8, i8* %p0, i64 3

  %r8 = trunc i32 %r to i8
  %g8 = trunc i32 %g to i8
  %b8 = trunc i32 %b to i8

  store i8 %r8, i8* %p0, align 1
  store i8 %g8, i8* %p1, align 1
  store i8 %b8, i8* %p2, align 1
  store i8 -1, i8* %p3, align 1
  br label %pixel_latch

pixel_latch:
  %i_next = add i32 %i, 1
  br label %pixel_loop

done:
  ret i32 %buf_i32
}

define i32 @get_buffer() {
entry:
  %ptr = load i32, i32* @buffer_ptr, align 4
  ret i32 %ptr
}

define i32 @get_buffer_size() {
entry:
  %size = load i32, i32* @buffer_size, align 4
  ret i32 %size
}

define void @free_buffer(i32 %ptr) {
entry:
  ret void
}

