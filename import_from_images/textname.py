import json

# Open and load the JSON file
with open('products.json', 'r') as file:
  products = json.load(file)
  # Filter products where product_name contains only numbers
numeric_products = [p for p in products if 'product_name' in p and not p['product_name'].isdigit()]

for product in numeric_products:
  print(product['product_name'])