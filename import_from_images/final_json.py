import json

# Open and load the JSON file
with open('products.json', 'r') as file:
  products = json.load(file)

final = []

for p in products:
  final.append({
    'name': p['product_name'],
    'color': p['color'],
    'type': p['type'],
    'quality': p['quality'],
    'image': p['processed_image_path'],
  });

with open('final.json', 'w') as file:
  json.dump(final, file, indent=2)