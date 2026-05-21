set_property ram_style block [get_cells program_rom/mem*]
set_property ram_style block [get_cells port_ram/mem*]

set_property dont_touch true [get_cells processor]
set_property dont_touch true [get_cells program_rom]
set_property dont_touch true [get_cells port_ram]
