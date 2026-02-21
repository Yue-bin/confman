--- 可用的command列表
local commands = {
    install = true,
    apply = true,
    grab = true,
    remove = true,
}

setmetatable(commands, {
    __index = function(_, input)
        input = input or ""
        Log:fatal("Unknown command: '" .. input .. "'")
        Log:info("Available commands: " .. table.concat(commands, ", "))
        os.exit(1)
    end
})

return commands
