; extends

[
  (autoescape_block)
  (block_block)
  (call_block)
  (filter_block)
  (for_block)
  (if_block)
  (macro_block)
  (raw_block)
  (set_block)
  (trans_block)
  (with_block)
] @block.outer

(autoescape_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(block_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(call_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(filter_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(for_block
  .
  (_)
  .
  (_)+ @block.inner @loop.inner
  .
  (_) .)

(if_block
  .
  (_)
  .
  (_)+ @block.inner @conditional.inner
  .
  (_) .)

(macro_block
  .
  (_)
  .
  (_)+ @block.inner @function.inner
  .
  (_) .)

(raw_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(set_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(trans_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(with_block
  .
  (_)
  .
  (_)+ @block.inner
  .
  (_) .)

(comment) @comment.outer

(if_block) @conditional.outer

(macro_block) @function.outer

(for_block) @loop.outer
