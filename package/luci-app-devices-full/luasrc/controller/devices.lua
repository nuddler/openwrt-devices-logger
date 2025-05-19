module("luci.controller.devices", package.seeall)

function index()
    entry({"admin", "status", "devices"}, template("devices/status"), "Urzędzenia sieciowe", 90)
end

