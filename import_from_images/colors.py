import json

# Open and load the JSON file
with open('products.json', 'r') as file:
  products = json.load(file)

unique_colors = set()
for product in products:
  color = product.get('color')
  if color:
    unique_colors.add(color)

# Print the unique colors
print(unique_colors)