//! One-shot native sensor snapshot for the System surface.
//! No crates: reads hwmon, power_supply and the ThinkPad fan interface.

use std::fs;
use std::path::{Path, PathBuf};

struct Sensor {
    label: String,
    unit: &'static str,
    value: String,
    kind: &'static str,
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

fn push(
    out: &mut Vec<Sensor>,
    label: &str,
    unit: &'static str,
    value: Option<f64>,
    kind: &'static str,
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
    });
}

fn main() {
    let mut ssd = Vec::new();
    let mut ram = Vec::new();
    let mut fans = Vec::new();
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
    push(&mut out, "CPU", "C", cpu, "temperature_core");
    for (index, value) in ssd.iter().enumerate() {
        push(
            &mut out,
            &format!("SSD{index}"),
            "C",
            Some(*value),
            "temperature_core",
        );
    }
    if igpu.is_some_and(|value| value > 0.0) {
        push(&mut out, "IGPU", "C", igpu, "temperature_core");
    }
    for (index, value) in ram.iter().enumerate() {
        push(
            &mut out,
            &format!("RAM{index}"),
            "C",
            Some(*value),
            "temperature_core",
        );
    }
    push(&mut out, "BAT", "%", battery, "battery");
    push(&mut out, "BAT RATE", "W", rate, "battery_power");
    push(&mut out, "POW RATE", "W", power, "amd_ppt");
    push(
        &mut out,
        "FAN RPM",
        "R",
        fans.into_iter().reduce(f64::max),
        "fan_speed",
    );
    push(&mut out, "FAN LEVEL", "", level, "fan_level");

    let json: Vec<String> = out
        .iter()
        .map(|sensor| {
            format!(
                "{{\"label\":\"{}\",\"unit\":\"{}\",\"value\":{},\"type\":\"{}\",\"key\":\"label\"}}",
                sensor.label.replace('"', "\\\""),
                sensor.unit,
                sensor.value,
                sensor.kind
            )
        })
        .collect();
    println!("{{\"sensors\":[{}]}}", json.join(","));
}
