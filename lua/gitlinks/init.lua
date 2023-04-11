local Config = require('gitlinks.config')
local Job = require('plenary.job')
local Path = require('plenary.path')

-- Gitlinks internal module
local G = {}

local function open_url(url)
  local cmd = vim.fn.has('macunix') == 1 and 'open' or 'xdg-open'
  Job:new({ command = cmd, args = { url } }):start()
end

local function get_linestr(rstart, rend)
  local linestr = ''
  if rstart and rstart > 0 then
    linestr = string.format('#L%d', rstart)
  end
  if rend and rend > rstart then
    linestr = string.format('%s-L%d', linestr, rend)
  end

  return linestr
end

local function startswith(str, prefix)
  return string.sub(str, 1, prefix:len()) == prefix
end

local function endswith(str, suffix)
  local lstr = str:len()
  local lsuf = suffix:len()
  return str:sub(lstr-lsuf+1, lstr) == suffix
end

local function wrn(msg) vim.notify('gitlinks: ' .. msg, vim.log.levels.WARN) end
local function err(msg) vim.notify('gitlinks: ' .. msg, vim.log.levels.ERROR) end
local function inf(msg) vim.notify('gitlinks: ' .. msg, vim.log.levels.INFO) end

local function copy_url(url)
  vim.api.nvim_command("let @+ = '" .. url .. "'")
  inf("copied url '" .. url .. "'")
end

function G.git(args, cwd)
  local output
  local exitcode
  Job:new({
    command = 'git',
    args = args,
    cwd = cwd or G.git_root(),
    on_exit = function(j, code)
      output = j:result()
      exitcode = code
    end,
  }):sync()
  return output, exitcode
end

function G.git_root(filepath)
  local fp = filepath or vim.api.nvim_buf_get_name(0)
  local res = G.git(
    {'rev-parse', '--show-toplevel'},
    tostring(Path:new(fp):parent())
  )[1]

  return res
end

function G.git_remote_url()
  local remote = G.git({'ls-remote', '--get-url'})[1]
  if remote then
  else
    return '', 'dir is not a git repo'
  end

  if startswith(remote, 'https://') then
    if endswith(remote, '.git') then
      remote = remote:sub(1, remote:len()-4)
    end
    return remote

  elseif startswith(remote, 'git@') then
    remote = remote:gsub(':', '/', 1)
    remote = remote:gsub('git@', 'https://', 1)
    if endswith(remote, '.git') then
      remote = remote:sub(1, remote:len()-4)
    end
    return remote
  end

  return '', 'could not determine git remote: ' .. remote
end

function G.git_repo_name()
  local remote_url = G.git_remote_url()
  local parts = vim.split(remote_url, '/', true)
  return parts[#parts]
end

function G.git_remote()
  return G.git({'remote'})[1]
end

function G.git_branch()
  return G.git({'rev-parse', '--abbrev-ref', 'HEAD'})[1]
end

function G.git_file_untracked()
  return G.i.file.path_full == '' or G.git({'ls-files', G.i.file.path_full}) == ''
end

function G.git_branch_untracked()
  local res = G.git({'config', '--get', 'branch.' .. G.i.git.branch .. '.remote'})[1]
  return res == nil or res == ''
end

function G.git_file_exists()
  local _, exitcode = G.git({'cat-file', '-e', G.i.git.remote..'/'..G.i.git.branch..':'..G.i.file.path_relative})
  return exitcode == 0
end

function G.git_file_dirty()
  local res = G.git({'status', '-s', G.i.file.path_relative})
  return res[1] ~= nil and res[1] ~= ''
end

function G.git_range_uncommitted()
  local range = G.i.range.vstart .. ',' .. G.i.range.vend
  local output = table.concat(G.git({'blame', G.i.file.path_full, '-L', range}), '')
  return output:find('Not Committed Yet') ~= nil
end

function G.git_url(linktype)
  local linestr = get_linestr(G.i.range.vstart, G.i.range.vend)

  if G.i.git.remote_url:find('github.com') then
    return string.format('%s/%s/%s/%s%s',
      G.i.git.remote_url,
      linktype,
      G.i.git.branch,
      G.i.file.path_relative,
      linestr)

  elseif G.i.git.remote_url:find('gitlab.com') then
    return string.format('%s/-/%s/%s/%s%s',
      G.i.git.remote_url,
      linktype,
      G.i.git.branch,
      G.i.file.path_relative,
      linestr)
  end

  return ''
end

function G.gitlinks(linktype, action, args)
  -- helper table to be used in module functions to avoid re-running git
  G.i = {
    range = {vstart = 0, vend = 0},
    file = {root = '', path_full = '', path_relative = ''},
    git = {remote = '', remote_url = '', branch = ''}
  }

  if linktype ~= 'blob' and linktype ~= 'blame' then
    err("unknown linktype '" .. action .. "'")
    return
  end

  if action ~= 'copy' and action ~= 'open' then
    err("unknown action '" .. action .. "'")
    return
  end

  local remote_url, error = G.git_remote_url()
  if remote_url == '' then
    err(error)
    return
  end

  G.i.git.remote_url = remote_url
  G.i.git.remote = G.git_remote()
  G.i.git.branch = G.git_branch()
  G.i.file.path_full = vim.api.nvim_buf_get_name(0)
  G.i.file.root = G.git_root(G.i.file.path_full) .. '/'
  G.i.file.path_relative = G.i.file.path_full:sub(G.i.file.root:len()+1)
  if args.range > 0 then
    G.i.range.vstart = args.line1
    G.i.range.vend = args.line2
  end

  if G.git_file_untracked() then
    err('cannot get link; file is untracked')
    return
  end

  if G.git_branch_untracked() then
    err('cannot get link; branch is untracked')
    return
  end

  if not G.git_file_exists() then
    err('file does not exist on remote and branch')
    return
  end

  if G.i.range.vstart > 0 and G.i.range.vend > 0 then
    if G.git_range_uncommitted() then
      err('selected range is uncommitted')
      return
    end

    if G.git_file_dirty() then
      wrn('file is dirty; selected ranges may be off')
    end
  end

  local url = G.git_url(linktype)
  if action == 'open' then
    open_url(url)
  else
    copy_url(url)
  end
end

-- Gitlinks main module
local M = {}

function M.setup(opts)
  Config.setup(opts)

  local cmdopts = {range = true, force = true}
  vim.api.nvim_create_user_command('GitlinkFileCopy', M.gitlink_file_copy, cmdopts)
  vim.api.nvim_create_user_command('GitlinkFileOpen', M.gitlink_file_open, cmdopts)
  vim.api.nvim_create_user_command('GitlinkBlameCopy', M.gitlink_blame_copy, cmdopts)
  vim.api.nvim_create_user_command('GitlinkBlameOpen', M.gitlink_blame_open, cmdopts)
end

function M.gitlink_file_copy(args) G.gitlinks('blob', 'copy', args) end
function M.gitlink_file_open(args) G.gitlinks('blob', 'open', args) end
function M.gitlink_blame_copy(args) G.gitlinks('blame', 'copy', args) end
function M.gitlink_blame_open(args) G.gitlinks('blame', 'open', args) end

return M
