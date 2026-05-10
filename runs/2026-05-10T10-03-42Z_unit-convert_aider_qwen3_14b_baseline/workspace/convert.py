import sys
import re
from enum import Enum

class UnitCategory(Enum):
    LENGTH = "length"
    MASS = "mass"
    VOLUME = "volume"
    TEMPERATURE = "temperature"
    SPEED = "speed"

class UnitConverter:
    def __init__(self):
        self.unit_info = {
            UnitCategory.LENGTH: {
                "mm": 0.001,
                "cm": 0.01,
                "m": 1,
                "km": 1000,
                "in": 0.0254,
                "ft": 0.3048,
                "yd": 0.9144,
                "mi": 1609.344,
                "mile": 1609.344,
                "miles": 1609.344
            },
            UnitCategory.MASS: {
                "mg": 0.001,
                "g": 1,
                "kg": 1000,
                "oz": 28.349523125,
                "lb": 453.59237,
                "lbs": 453.59237
            },
            UnitCategory.VOLUME: {
                "ml": 0.001,
                "l": 1,
                "gal": 3.785411784
            },
            UnitCategory.SPEED: {
                "mph": 0.44704,
                "kph": 0.277778,
                "m/s": 1
            }
        }
        self.temperature_conversions = {
            "c": {
                "f": lambda x: (x * 9/5) + 32,
                "k": lambda x: x + 273.15
            },
            "f": {
                "c": lambda x: (x - 32) * 5/9,
                "k": lambda x: (x - 32) * 5/9 + 273.15
            },
            "k": {
                "c": lambda x: x - 273.15,
                "f": lambda x: (x - 273.15) * 9/5 + 32
            }
        }

    def parse_input(self, input_str):
        parts = input_str.split(" to ")
        if len(parts) != 2:
            self._error("Invalid format. Expected: '<value> <unit> ... to <target_unit>'")
        
        source_part, target_unit = parts
        source_tokens = re.findall(r"([0-9.]+)\s+([a-zA-Z]+)", source_part)
        
        if not source_tokens:
            self._error("No values found in input")
        
        values = []
        units = []
        for value_str, unit in source_tokens:
            try:
                value = float(value_str)
                values.append(value)
                units.append(unit.lower())
            except ValueError:
                self._error(f"Invalid value: {value_str}")
        
        return values, units, target_unit.lower()

    def get_category(self, unit):
        for category, units in self.unit_info.items():
            if unit in units:
                return category
        if unit in self.temperature_conversions:
            return UnitCategory.TEMPERATURE
        self._error(f"Unknown unit: {unit}")

    def validate_units(self, units):
        category = self.get_category(units[0])
        for unit in units:
            if self.get_category(unit) != category:
                self._error(f"Units must be in the same category. Got: {units}")
        if category == UnitCategory.TEMPERATURE and len(units) > 1:
            self._error("Temperature conversions cannot be summed. Use a single value only.")

    def convert(self, values, units, target_unit):
        category = self.get_category(units[0])
        self.validate_units(units)
        
        if category == UnitCategory.TEMPERATURE:
            return self._convert_temperature(values[0], units[0], target_unit)
        
        base_unit = next(iter(self.unit_info[category]))
        base_value = 0
        
        for value, unit in zip(values, units):
            conversion_factor = self.unit_info[category][unit]
            base_value += value * conversion_factor
        
        target_conversion_factor = self.unit_info[category].get(target_unit)
        if not target_conversion_factor:
            self._error(f"Unknown target unit: {target_unit}")
        
        result = base_value / target_conversion_factor
        return round(result, 4)

    def _convert_temperature(self, value, from_unit, to_unit):
        if from_unit not in self.temperature_conversions or to_unit not in self.temperature_conversions[from_unit]:
            self._error(f"Invalid temperature conversion: {from_unit} to {to_unit}")
        
        return round(self.temperature_conversions[from_unit][to_unit](value), 4)

    def _error(self, message):
        sys.stderr.write(f"error: {message}\n")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("error: Missing expression\n")
        sys.exit(1)
    
    input_str = sys.argv[1]
    converter = UnitConverter()
    values, units, target_unit = converter.parse_input(input_str)
    result = converter.convert(values, units, target_unit)
    print(f"{result:.4f} {target_unit}")

if __name__ == "__main__":
    main()
