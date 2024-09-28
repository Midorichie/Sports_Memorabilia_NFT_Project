# File: app.py
from flask import Flask, jsonify, request
from web3 import Web3
import json

app = Flask(__name__)

# Connect to a local Ethereum node (replace with your node URL)
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))

# Load ABI and contract address (you'll need to deploy the contract first)
with open('contract_abi.json', 'r') as abi_file:
    contract_abi = json.load(abi_file)

contract_address = '0x1234567890123456789012345678901234567890'  # Replace with actual address
contract = w3.eth.contract(address=contract_address, abi=contract_abi)

@app.route('/mint_nft', methods=['POST'])
def mint_nft():
    data = request.json
    token_id = data['token_id']
    metadata_uri = data['metadata_uri']
    owner_address = data['owner_address']

    # Call the smart contract function to mint the NFT
    tx_hash = contract.functions.mintNFT(token_id, metadata_uri, owner_address).transact()
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    return jsonify({"success": True, "transaction_hash": receipt.transactionHash.hex()})

@app.route('/get_nft/<int:token_id>', methods=['GET'])
def get_nft(token_id):
    # Call the smart contract function to get NFT details
    owner = contract.functions.ownerOf(token_id).call()
    metadata_uri = contract.functions.tokenURI(token_id).call()

    return jsonify({"token_id": token_id, "owner": owner, "metadata_uri": metadata_uri})

if __name__ == '__main__':
    app.run(debug=True)

# File: smart_contract.clar
(define-non-fungible-token sports-nft uint)

(define-data-var last-token-id uint u0)

(define-public (mint-nft (metadata-uri (string-utf8 256)) (recipient principal))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    (try! (nft-mint? sports-nft token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-read-only (get-token-uri (token-id uint))
  (ok (nft-get-uri? sports-nft token-id))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? sports-nft token-id))
)

# File: requirements.txt
Flask==2.0.1
web3==5.23.0