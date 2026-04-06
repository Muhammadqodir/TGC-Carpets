import json

# Open and load the JSON file
with open('products.json', 'r') as file:
  products = json.load(file)

for product in products:
  if product['product_name'] not in product['original_filename']:
    print(product['original_filename'])

