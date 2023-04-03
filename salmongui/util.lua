local util = {}

function util.drawBox(gpu, x, y, width, height, heading)
    gpu.fill(x + 1, y, width, 1, "─")
    gpu.fill(x + 1, y + height - 1, width, 1, "─")
    gpu.fill(x, y + 1, 1, height - 2, "│")
    gpu.fill(x + width, y + 1, 1, height - 2, "│")
    gpu.set(x, y, "╭")
    gpu.set(x + width, y, "╮")
    gpu.set(x, y + height - 1, "╰")
    gpu.set(x + width, y + height - 1, "╯")

    if heading ~= nil then
        gpu.set(x + 1, y, heading)
    end
end

return util