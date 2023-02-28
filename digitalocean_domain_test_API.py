#!/usr/bin/env python3
import requests
import json
import gnupg

# Initialize GPG object
gpg = gnupg.GPG()
gpg_file='./digitalocean_api_token.txt.gpg'

# Also, make sure:
#  1. Have pinentry installed to handle your PGP prompt
#  2. Clear agent on the console before with: "gpg-connect-agent reloadagent /bye"
with open(gpg_file, 'rb') as f:
    decrypted_data = gpg.decrypt_file(f)
    TOKEN=str(decrypted_data).strip()

# Define the Auth Headers for the API
headers = {
           'Content-Type': 'application/json',
           'Authorization': 'Bearer ' + TOKEN
}

# Set up the API endpoint URL
url = 'https://api.digitalocean.com/v2/domains'

# Define the parameters for the new domain
domain_name = 'test2.do.cero32.cl'
ip_address = '143.198.73.162'

# Define the data for the new domain
data = {
    'name': domain_name,
    'ip_address': ip_address,
}

# Make the request to create the new domain
response = requests.post(url, headers=headers, data=json.dumps(data))
# Check the response for errors
if response.status_code == 201:
    print(f'Successfully created domain {domain_name}')
else:
    print(f'Error creating domain {domain_name}: {response.status_code} {response.reason}')


######################################
# Make a request to list all domains
response = requests.get(url, headers=headers)

if response.status_code == 200:
    # Loop through list of domains and print their names
    domains = response.json()['domains']
    for domain in domains:
        print(domain['name'])
else:
    # Print error message if response was not successful
    print('Error:', response.status_code, response.text)


########################################
# Delete the domain
endpoint = f"https://api.digitalocean.com/v2/domains/{domain_name}"

# Send the DELETE request
response = requests.delete(endpoint, headers=headers)

if response.status_code == 204:
    print(f"The domain {domain_name} was successfully deleted.")
else:
    print(f"Failed to delete the domain {domain_name}. Error {response.status_code}: {response.json()['message']}")
