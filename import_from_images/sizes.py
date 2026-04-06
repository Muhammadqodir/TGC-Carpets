import json
from collections import defaultdict

with open('products.json', 'r') as file:
    products = json.load(file)

sizes_by_type = defaultdict(set)

for p in products:
    w, l = p.get('width_cm'), p.get('length_cm')
    if w and l:
        sizes_by_type[p['type']].add((w, l))

for product_type, sizes in sorted(sizes_by_type.items()):
    sorted_sizes = sorted(sizes)
    print(f"{product_type}:")
    for w, l in sorted_sizes:
        print(f"  {w}x{l} cm")



