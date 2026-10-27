//! One-shot native sensor snapshot for the System surface.
//! No crates: reads hwmon, power_supply and the ThinkPad fan interface.

use std::fs;
use std::path::{Path, PathBuf};

struct Sensor {
    label: String,
    unit: &'static str,
    value: String,
    kind: &'static str,
    group: &'static str,
}

fn read(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

fn number(path: &Path, divisor: f64) -> Option<f64> {
    read(path)?.parse::<f64>().ok().map(|v| v / divisor)
}

fn hwmons() -> Vec<(PathBuf, String)> {
    let mut out = Vec::new();
    let Ok(entries) = fs::read_dir("/sys/class/hwmon") else {
        return out;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        out.push((path.clone(), read(&path.join("name")).unwrap_or_default()));
    }
    out
}

fn push_group(
    out: &mut Vec<Sensor>,
    label: &str,
    unit: &'static str,
    value: Option<f64>,
    kind: &'static str,
    group: &'static str,
) {
    let Some(mut value) = value else { return };
    if kind == "temperature_core" {
        value = value.round();
    }
    let text = if (value - value.round()).abs() < 0.05 {
        format!("{}", value.round() as i64)
    } else {
        format!("{value:.1}")
    };
    out.push(Sensor {
        label: label.to_string(),
        unit,
        value: text,
        kind,
        group,
    });
}

#[allow(dead_code)]
fn push(
    out: &mut Vec<Sensor>,
    label: &str,
    unit: &'static str,
    value: Option<f64>,
    kind: &'static str,
) {
    push_group(out, label, unit, value, kind, "Other");
}

fn dir_value(path: &Path, file: &str, divisor: f64, unit: &'static str, kind: &'static str,
             group: &'static str, out: &mut Vec<Sensor>, prefix: &str) {
    let Some(value) = number(&path.join(file), divisor) else { return };
    let label = read(&path.join(file.replace("_input", "_label")))
        .filter(|label| !label.is_empty())
        .map(|label| format!("{prefix} {label}"))
        .unwrap_or_else(|| format!("{prefix} {}", file.trim_end_matches("_input")));
    push_group(out, &label, unit, Some(value), kind, group);
}

fn scan_hwmon(out: &mut Vec<Sensor>) {
    for (path, chip) in hwmons() {
        let Ok(entries) = fs::read_dir(&path) else { continue };
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            let value_path = entry.path();
            if !value_path.is_file() {
                continue;
            }
            let pairs: [(&str, f64, &'static str, &'static str, &'static str); 8] = [
                ("temp", 1000.0, "C", "temperature_core", "Temperatures"),
                ("in", 1000.0, "V", "voltage", "Voltages"),
                ("curr", 1000.0, "A", "current", "Currents"),
                ("power", 1000000.0, "W", "power", "Power"),
                ("energy", 1000000.0, "J", "energy", "Energy"),
                ("fan", 1.0, "R", "fan_speed", "Fans"),
                ("pwm", 1.0, "PWM", "pwm", "Fans"),
                ("freq", 1000000.0, "MHz", "frequency", "Clocks"),
            ];
            for (prefix, divisor, unit, kind, group) in pairs {
                let Some(rest) = name.strip_prefix(prefix) else { continue };
                let Some(base) = rest.strip_suffix("_input") else {
                    if prefix == "pwm" && rest.chars().all(|c| c.is_ascii_digit()) {
                        dir_value(&path, &name, divisor, unit, kind, group, out, &chip);
                    }
                    continue;
                };
                if !base.chars().all(|c| c.is_ascii_digit()) {
                    continue;
                }
                dir_value(&path, &format!("{prefix}{base}_input"), divisor, unit, kind, group, out, &chip);
            }
        }
    }
}

fn scan_power_supply(out: &mut Vec<Sensor>) {
    let Ok(entries) = fs::read_dir("/sys/class/power_supply") else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        let supply_type = read(&path.join("type")).unwrap_or_default();
        let group = match supply_type.as_str() {
            "Battery" => "Battery",
            "USB" => "USB-C",
            "Mains" | "ADP" => "Power supply",
            _ if name.starts_with("AC") => "Power supply",
            _ => "Power supply",
        };
        for (file, divisor, unit, kind, _base_group) in [
            ("voltage_now", 1000000.0, "V", "voltage", "Battery"),
            ("current_now", 1000000.0, "A", "current", "Battery"),
            ("power_now", 1000000.0, "W", "power", "Battery"),
            ("energy_now", 1000000.0, "Wh", "energy", "Battery"),
            ("energy_full", 1000000.0, "Wh", "energy", "Battery"),
            ("energy_full_design", 1000000.0, "Wh", "energy", "Battery"),
            ("capacity", 1.0, "%", "battery", "Battery"),
            ("cycle_count", 1.0, "cycles", "battery", "Battery"),
            ("online", 1.0, "", "battery", "Battery"),
            ("charge_control_start_threshold", 1.0, "%", "battery", "Battery"),
            ("charge_control_end_threshold", 1.0, "%", "battery", "Battery"),
        ] {
            if let Some(value) = number(&path.join(file), divisor) {
                let label = format!("{name} {}", file.replace('_', " "));
                let group = if kind == "battery" && file == "capacity" {
                    "Battery"
                } else {
                    group
                };
                push_group(out, &label, unit, Some(value), kind, group);
            }
        }
    }
}

fn scan_thermal(out: &mut Vec<Sensor>) {
    let Ok(entries) = fs::read_dir("/sys/class/thermal") else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if !entry.file_name().to_string_lossy().starts_with("thermal_zone") {
            continue;
        }
        let zone = read(&path.join("type")).unwrap_or_else(|| entry.file_name().to_string_lossy().to_string());
        if let Some(value) = number(&path.join("temp"), 1000.0) {
            push_group(out, &format!("TZ {zone}"), "C", Some(value), "temperature_core", "Temperatures");
        }
    }
}

fn main() {
    let mut ssd = Vec::new();
    let mut ram = Vec::new();
    let mut fans = Vec::new();
    let mut fan_seen = false;
    let mut cpu = None;
    let mut igpu = None;
    let mut power = None;
    let mut battery = None;
    let mut rate = None;

    for (path, name) in hwmons() {
        match name.as_str() {
            "k10temp" => {
                for file in ["temp1_input", "temp2_input", "temp3_input"] {
                    if let Some(value) = number(&path.join(file), 1000.0) {
                        cpu = Some(value);
                        break;
                    }
                }
            }
            "amdgpu" => {
                igpu = number(&path.join("temp1_input"), 1000.0);
                power = number(&path.join("power1_input"), 1_000_000.0);
            }
            "nvme" => {
                if let Some(value) = number(&path.join("temp1_input"), 1000.0) {
                    ssd.push(value);
                }
            }
            "spd5118" => {
                if let Some(value) = number(&path.join("temp1_input"), 1000.0) {
                    ram.push(value);
                }
            }
            "acpi_fan" => {
                if let Some(value) = number(&path.join("fan1_input"), 1.0) {
                    fan_seen = true;
                    if value > 0.0 {
                        fans.push(value);
                    }
                }
            }
            "thinkpad" => {
                if cpu.is_none() {
                    cpu = number(&path.join("temp1_input"), 1000.0);
                }
                if igpu.is_none() {
                    igpu = number(&path.join("temp2_input"), 1000.0).filter(|v| *v > 0.0);
                }
            }
            _ => {}
        }
        if let Ok(entries) = fs::read_dir(&path) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("fan") && name.ends_with("_input") {
                    if let Some(value) = number(&entry.path(), 1.0) {
                        fan_seen = true;
                        if value > 0.0 {
                            fans.push(value);
                        }
                    }
                }
            }
        }
    }

    if let Ok(entries) = fs::read_dir("/sys/class/power_supply") {
        for entry in entries.flatten() {
            let path = entry.path();
            if read(&path.join("type")).as_deref() != Some("Battery") {
                continue;
            }
            battery = number(&path.join("capacity"), 1.0);
            rate = number(&path.join("power_now"), 1_000_000.0);
            if rate.is_none() {
                if let (Some(current), Some(voltage)) = (
                    number(&path.join("current_now"), 1_000_000.0),
                    number(&path.join("voltage_now"), 1_000_000.0),
                ) {
                    rate = Some(current * voltage);
                }
            }
            break;
        }
    }

    let fan = read(Path::new("/proc/acpi/ibm/fan"));
    let level = fan.and_then(|text| {
        text.lines()
            .find_map(|line| line.strip_prefix("level:"))?
            .trim()
            .parse::<f64>()
            .ok()
    });

    let mut out = Vec::new();
    push_group(&mut out, "CPU", "C", cpu, "temperature_core", "Temperatures");
    for (index, value) in ssd.iter().enumerate() {
        push_group(
            &mut out,
            &format!("SSD{index}"),
            "C",
            Some(*value),
            "temperature_core",
            "Temperatures",
        );
    }
    if igpu.is_some_and(|value| value > 0.0) {
        push_group(&mut out, "IGPU", "C", igpu, "temperature_core", "Temperatures");
    }
    for (index, value) in ram.iter().enumerate() {
        push_group(
            &mut out,
            &format!("RAM{index}"),
            "C",
            Some(*value),
            "temperature_core",
            "Temperatures",
        );
    }
    push_group(&mut out, "BAT", "%", battery, "battery", "Battery");
    push_group(&mut out, "BAT RATE", "W", rate, "battery_power", "Battery");
    push_group(&mut out, "POW RATE", "W", power, "amd_ppt", "Power");
    if fan_seen || level.is_some() {
        push_group(
            &mut out,
            "FAN RPM",
            "R",
            fans.into_iter().reduce(f64::max).or(Some(0.0)),
            "fan_speed",
            "Fans",
        );
    }
    push_group(&mut out, "FAN LEVEL", "", level, "fan_level", "Fans");

    scan_hwmon(&mut out);
    scan_power_supply(&mut out);
    scan_thermal(&mut out);

    let json: Vec<String> = out
        .iter()
        .map(|sensor| {
            format!(
                "{{\"label\":\"{}\",\"unit\":\"{}\",\"value\":{},\"type\":\"{}\",\"group\":\"{}\",\"key\":\"label\"}}",
                sensor.label.replace('"', "\\\""),
                sensor.unit,
                sensor.value,
                sensor.kind,
                sensor.group
            )
        })
        .collect();
    println!("{{\"sensors\":[{}]}}", json.join(","));
}
