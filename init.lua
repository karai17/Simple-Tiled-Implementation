local path       = (...):gsub('%.', '/'):gsub('/init$', '') .. "/"
return require(path .. 'sti')
