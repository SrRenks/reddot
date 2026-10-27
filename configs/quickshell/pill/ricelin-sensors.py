#!/usr/bin/env python3
"""Read the machine sensors once, in one short process, using hwmon/sysfs."""
import glob
import json
import os


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def number(path, scale=1.0):
    raw = read(path)
    try:
        return float(raw) / scale
    except ValueError:
        return None


def add(items, label, unit, value, kind):
    if value is None:
        return
    items.append({
        "label": label,
        "unit": unit,
        "value": value,
        "type": kind,
        "key": "label",
    })


def main():
    items = []
    hwmons = []
    for path in glob.glob("/sys/class/hwmon/hwmon*"):
        hwmons.append((path, read(os.path.join(path, "name"))))

    cpu = None
    igpu = None
    fans = []
    power_w = None
    ssd = 0
    ram = 0

    for path, name in hwmons:
        if name == "k10temp":
            for candidate in ("temp1_input", "temp2_input", "temp3_input"):
                value = number(os.path.join(path, candidate), 1000.0)
                if value is not None:
                    cpu = value
                    break
        elif name == "amdgpu":
            igpu = number(os.path.join(path, "temp1_input"), 1000.0)
            power_w = number(os.path.join(path, "power1_input"), 1000000.0)
        elif name == "nvme":
            value = number(os.path.join(path, "temp1_input"), 1000.0)
            if value is not None:
                add(items, "SSD%d" % ssd, "C", round(value), "temperature_core")
                ssd += 1
        elif name == "spd5118":
            value = number(os.path.join(path, "temp1_input"), 1000.0)
            if value is not None:
                add(items, "RAM%d" % ram, "C", round(value), "temperature_core")
                ram += 1
        for fan_path in glob.glob(os.path.join(path, "fan*_input")):
            value = number(fan_path)
            if value is not None and value > 0:
                fans.append(round(value))

    if cpu is None:
        for path, name in hwmons:
            if name == "thinkpad":
                cpu = number(os.path.join(path, "temp1_input"), 1000.0)
                break
    if not fans:
        for path, name in hwmons:
            if name == "acpi_fan":
                value = number(os.path.join(path, "fan1_input"))
                if value is not None:
                    fans.append(round(value))
    if igpu is None:
        for path, name in hwmons:
            if name == "thinkpad":
                igpu = number(os.path.join(path, "temp2_input"), 1000.0)
                break

    add(items, "CPU", "C", round(cpu) if cpu is not None else None, "temperature_core")
    if igpu is not None and igpu > 0:
        add(items, "IGPU", "C", round(igpu), "temperature_core")

    battery = None
    for supply in glob.glob("/sys/class/power_supply/*"):
        if read(os.path.join(supply, "type")) != "Battery":
            continue
        capacity = number(os.path.join(supply, "capacity"))
        if capacity is not None:
            battery = capacity
        rate = number(os.path.join(supply, "power_now"), 1000000.0)
        if rate is None:
            current = number(os.path.join(supply, "current_now"), 1000000.0)
            voltage = number(os.path.join(supply, "voltage_now"), 1000000.0)
            if current is not None and voltage is not None:
                rate = current * voltage
        add(items, "BAT", "%", round(battery) if battery is not None else None,
            "battery")
        add(items, "BAT RATE", "W",
            round(rate, 1) if rate is not None else None, "battery_power")
        break

    if power_w is not None:
        add(items, "POW RATE", "W", round(power_w, 1), "amd_ppt")

    fan = read("/proc/acpi/ibm/fan")
    level = None
    for line in fan.splitlines():
        if line.startswith("level:"):
            try:
                level = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
    if fans:
        add(items, "FAN RPM", "R", max(fans), "fan_speed")
    if level is not None:
        add(items, "FAN LEVEL", "", level, "fan_level")

    order = {
        "CPU": 0, "SSD0": 1, "SSD1": 2, "IGPU": 3,
        "RAM0": 4, "RAM1": 5,
        "BAT": 6, "BAT RATE": 7, "POW RATE": 8,
        "FAN RPM": 9, "FAN LEVEL": 10,
    }
    items.sort(key=lambda item: order.get(item["label"], 99))
    print(json.dumps({"sensors": items}, separators=(",", ":")))


if __name__ == "__main__":
    main()
