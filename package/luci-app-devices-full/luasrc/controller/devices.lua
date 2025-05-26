-- /usr/lib/lua/luci/controller/devices.lua
module("luci.controller.devices", package.seeall)

function index()
  entry({"admin", "status", "devices"}, call("action_status"), _("Device Status"), 60)
end

function action_status()
  local uci = require "luci.model.uci".cursor()
  local sys = require "luci.sys"
  local tpl = require "luci.template"

  -- 1) Statyczne hosty
  local stat_map = {}
  uci:foreach("dhcp", "host", function(s)
    local mac = s.mac
    if type(mac) == "table" then mac = mac[1] end
    if mac and s.name then
      stat_map[string.lower(mac)] = s.name
    end
  end)

  -- 2) Dynamiczne dzierżawy
  local dyn_map = {}
  local fh = io.open("/tmp/dhcp.leases", "r")
  if fh then
    for line in fh:lines() do
      local ts, mac, ip, host = line:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
      if mac and host then
        dyn_map[string.lower(mac)] = host
      end
    end
    fh:close()
  end

  -- 3) ARP-scan i zbieranie danych
  local data = {}
  local arp = io.popen("arp-scan --interface=br-lan --localnet 2>/dev/null")
  for line in arp:lines() do
    local ip, mac = line:match("^(%d+%.%d+%.%d+%.%d+)%s+(%S+)")
    if ip and mac then
      mac = string.lower(mac)
      local hostname = dyn_map[mac] or stat_map[mac] or "N/A"
      local typ  = "LAN"
      local port = "N/A"

      -- a) Wi-Fi na AP-ifaces
      local ifs = sys.exec("iw dev 2>/dev/null | awk '$1==\"Interface\"{print $2}'") or ""
      for ifname in ifs:gmatch("[^\r\n]+") do
        local info = sys.exec("iw dev " .. ifname .. " info 2>/dev/null") or ""
        if info:match("type AP") then
          local dump = sys.exec("iw dev " .. ifname .. " station dump 2>/dev/null") or ""
          if dump:lower():match("station " .. mac) then
            local essid = sys.exec(
              "iwinfo " .. ifname ..
              " info 2>/dev/null | awk -F'\"' '/ESSID/ {print $2}'"
            ) or ""
            typ = essid:match("%S+") or "N/A"
            break
          end
        end
      end

      -- b) Port LAN
      if typ == "LAN" then
        local tbl = sys.exec("brctl showmacs br-lan 2>/dev/null") or ""
        for ln in tbl:gmatch("[^\r\n]+") do
          local row = ln:match("^%s*(.*)") or ln
          local p, m = row:match("^(%d+)%s+(%S+)")
          if m and string.lower(m) == mac then
            port = p
            typ  = "LAN"
            break
          end
        end
      end

      table.insert(data, {
        ip       = ip,
        mac      = mac,
        hostname = hostname,
        port     = port,
        typ      = typ
      })
    end
  end
  arp:close()

  -- 4) Render
  tpl.render("devices/status", { devices = data })
end
