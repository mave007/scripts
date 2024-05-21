#!/usr/bin/env python3
import requests
import json
import gnupg  # pip3 install python-gnupg

# Initialize GPG object
gpg = gnupg.GPG()
gpg_file='./digitalocean_api_token.txt.gpg'

# Also, make sure:
#  1. Have pinentry installed to handle your PGP prompt
#  2. Clear agent on the console before with: "gpg-connect-agent reloadagent /bye"
with open(gpg_file, 'rb') as f:
    decrypted_data = gpg.decrypt_file(f)
    TOKEN=str(decrypted_data).strip()
    #print(TOKEN)

# Define the Auth Headers for the API
headers = {
           'Content-Type': 'application/json',
           'Authorization': 'Bearer ' + TOKEN
}

def AddRR(rname,rtype,rdata,rttl=None,rweight=None,rpriority=None):
    """
    This function adds a Resource Record given string `dom` associated to string `ip`
    
    Parameters:
    (req) rname (str): owner name (label)
    (req) rtype (str): type of DNS Record (example: A, CNAME, TXT)
    (req) rdata (str): a variable length string of octets that describes the resource. The format of this information varies according to the TYPE and CLASS of the resource record.
    (opt) rttl (int): TTL of the record
    (opt) rweight (int): weight for SRV records
    (opt) rpriority (int): priority of SRV or MX records

    
    Returns: 
    None
    """
    
    data = {
            'name': rname,
            'type': rtype,
            'data': rdata,
            'ttl': rttl,
            'weight': rweight,
            'priority': rpriority,
    }
    
    url = 'https://api.digitalocean.com/v2/domains'
    response = requests.post(url, headers=headers, data=json.dumps(data))
    if response.status_code == 201:
        print(f'Successfully created domain {rname} {rtype} {rdata}')
    else:
        print(f'Error creating domain {rname}: {response.status_code} {response.reason}')

def ListRR():
    """ 
    Make a request to list all domains
    """
    
    url = 'https://api.digitalocean.com/v2/domains'
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        # Loop through list of domains and print their names
        domains = response.json()['domains']
        for domain in domains:
            print(domain['name'])
    else:
        # Print error message if response was not successful
        print('Error:', response.status_code, response.text)


def DelRR(dom):
    """
    Delete the domain given
    
    Parameters: 
    dom (str): FQDN
    
    Returns:
    None
    """
    endpoint = f"https://api.digitalocean.com/v2/domains/{dom}"
    response = requests.delete(endpoint, headers=headers)
    
    if response.status_code == 204:
        print(f"The domain {dom} was successfully deleted.")
    else:
        print(f"Failed to delete the domain {domain_name}. Error {response.status_code}: {response.json()['message']}")


#AddRR("sfo.test.do.cero32.cl",'143.198.73.162')
#DelRR("nyc.test.do.cero32.cl")
#AddRR("nyc.test.do.cero32.cl",'138.197.4.218')

AddRR('nyc.test.do.cero32.cl', 'TXT', ' test')
ListRR
