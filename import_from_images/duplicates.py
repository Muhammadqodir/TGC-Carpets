import json

# Open and load the JSON file
with open('products.json', 'r') as file:
  products = json.load(file)

  seen = set()
  duplicates = []

  for product in products:
    key = (product.get('product_name'), product.get('color'), product.get('quality'), product.get('type'))
    if key in seen:
      duplicates.append(product)
    else:
      seen.add(key)

  print(f"Found {len(duplicates)} duplicate(s):")
  for dup in duplicates:
    print(f"  - {dup.get('product_name')} ({dup.get('color')}) - {dup.get('quality')} - {dup.get('type')}")