# File: app.py
from flask import Flask, jsonify, request
from web3 import Web3
import json
from datetime import datetime
import ipfshttpclient

app = Flask(__name__)

# Connect to a local Ethereum node (replace with your node URL)
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))

# Load ABI and contract address
with open('contract_abi.json', 'r') as abi_file:
    contract_abi = json.load(abi_file)

contract_address = '0x1234567890123456789012345678901234567890'  # Replace with actual address
contract = w3.eth.contract(address=contract_address, abi=contract_abi)

# Connect to IPFS
ipfs_client = ipfshttpclient.connect('/ip4/127.0.0.1/tcp/5001')

@app.route('/mint_nft', methods=['POST'])
def mint_nft():
    try:
        data = request.json
        owner_address = data['owner_address']
        athlete_name = data['athlete_name']
        item_description = data['item_description']
        event_date = data['event_date']
        
        # Create metadata
        metadata = {
            "name": f"{athlete_name} Memorabilia",
            "description": item_description,
            "athlete": athlete_name,
            "event_date": event_date,
            "minted_date": datetime.now().isoformat()
        }
        
        # Upload metadata to IPFS
        ipfs_hash = ipfs_client.add_json(metadata)
        metadata_uri = f"ipfs://{ipfs_hash}"
        
        # Call the smart contract function to mint the NFT
        tx_hash = contract.functions.mintNFT(metadata_uri, owner_address).transact()
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        token_id = contract.functions.getLastTokenId().call()
        
        return jsonify({
            "success": True,
            "token_id": token_id,
            "transaction_hash": receipt.transactionHash.hex(),
            "metadata_uri": metadata_uri
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/get_nft/<int:token_id>', methods=['GET'])
def get_nft(token_id):
    try:
        # Call the smart contract function to get NFT details
        owner = contract.functions.ownerOf(token_id).call()
        metadata_uri = contract.functions.tokenURI(token_id).call()
        
        # Fetch metadata from IPFS
        ipfs_hash = metadata_uri.split("://")[1]
        metadata = ipfs_client.cat(ipfs_hash)
        
        return jsonify({
            "token_id": token_id,
            "owner": owner,
            "metadata_uri": metadata_uri,
            "metadata": json.loads(metadata)
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/transfer_nft', methods=['POST'])
def transfer_nft():
    try:
        data = request.json
        from_address = data['from_address']
        to_address = data['to_address']
        token_id = data['token_id']
        
        tx_hash = contract.functions.transferFrom(from_address, to_address, token_id).transact()
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        return jsonify({
            "success": True,
            "transaction_hash": receipt.transactionHash.hex()
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

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

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u403))
    (nft-transfer? sports-nft token-id sender recipient)
  )
)

(define-read-only (get-token-uri (token-id uint))
  (ok (nft-get-uri? sports-nft token-id))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? sports-nft token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

# File: requirements.txt
Flask==2.0.1
web3==5.23.0
ipfshttpclient==0.8.0