return {
  'nvim-mini/mini.misc',
  version = '*',
  lazy = false,
  config = function ()
    require('mini.misc').setup({
      make_global = { 'put', 'put_text', 'setup_auto_root' },
    })
  end
}
