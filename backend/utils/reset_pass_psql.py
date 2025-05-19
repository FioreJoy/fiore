import bcrypt

# The new password you want to set
new_password = "x"

# Generate salt
salt = bcrypt.gensalt(rounds=10)

# Hash the password
hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), salt)

# Print the hash
print("New bcrypt hash:", hashed_password.decode('utf-8'))
