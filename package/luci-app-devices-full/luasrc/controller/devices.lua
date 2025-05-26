module("luci.controller.devices", package.seeall)

function index()
  entry({"admin", "status", "devices"}, call("action_status"), "Urządzenia sieciowe", 90)
end

function action_status()
  local sys  = require "luci.sys"
  local tpl  = require "luci.template"
  local data = {}

  -- wczytaj DHCP leases
  local leases   = sys.exec("cat /tmp/dhcp.leases")
  -- wczytaj sąsiadów z br-lan
  local neigh    = sys.exec("ip neigh show dev br-lan")

  -- znajdź interfejsy Wi-Fi i ich SSID
  local wifi_ifs, wifi_label = {}, {}
  for iface in sys.exec("iw dev | awk '$1==\"Interface\"{print $2}'"):gmatch("%S+") do
    table.insert(wifi_ifs, iface)
    local ssid = sys.exec(
      "iw dev " .. iface .. " info | grep '\\<ssid\\>' | cut -d ' ' -f2-"
    ):match("^%s*(.-)%s*$")
    wifi_label[iface] = (ssid ~= "" and ssid) or iface
  end

  -- funkcja pomocnicza do znajdowania portu
  local function find_port(mac, ip)
    local port_no = sys.exec(
      "brctl showmacs br-lan 2>/dev/null | grep -i " .. mac .. " | awk '{print $1}'"
    ):match("%d+")
    if not port_no then
      sys.exec("ping -c1 -W1 " .. ip .. " >/dev/null 2>&1")
      port_no = sys.exec(
        "brctl showmacs br-lan 2>/dev/null | grep -i " .. mac .. " | awk '{print $1}'"
      ):match("%d+")
    end
    if not port_no then
      return "-"
    end
    local line = sys.exec(
      "brctl show br-lan | sed -n '2,$p' | awk '{print $NF}' | sed -n " .. port_no .. "p"
    )
    return (line:match("%S+") or "-")
  end

  -- parsuj każdy wiersz z neigh
  for ln in neigh:gmatch("[^\n]+") do
    local ip, mac = ln:match("(%d+%.%d+%.%d+%.%d+).*lladdr%s+([0-9a-f:]+)")
    if ip and mac then
      mac = mac:lower()
      local hostname = leases:match("%S+%s+"..mac.."%s+%S+%s+(%S+)") or "-"
      local port     = find_port(mac, ip)
      local typ

      if wifi_label[port] then
        typ  = wifi_label[port]
        port = "-"
      else
        typ = "LAN"
      end

      -- dodatkowa weryfikacja po station dump
      for _, iface in ipairs(wifi_ifs) do
        if sys.exec(
          "iw dev " .. iface .. " station dump | grep -iq " .. mac .. " && echo yes"
        ):match("yes") then
          typ  = wifi_label[iface]
          port = "-"
          break
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

  -- renderujemy z przekazaniem gotowej listy
  tpl.render("devices/status", { devices = data })
end