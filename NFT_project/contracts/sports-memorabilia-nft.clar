# File: app.py
from flask import Flask, jsonify, request, render_template
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity
from web3 import Web3
import json
from datetime import datetime, timedelta
import ipfshttpclient
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = 'your-secret-key'  # Change this!
jwt = JWTManager(app)

# Connect to a local Ethereum node (replace with your node URL)
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))

# Load ABI and contract address
with open('contract_abi.json', 'r') as abi_file:
    contract_abi = json.load(abi_file)

contract_address = '0x1234567890123456789012345678901234567890'  # Replace with actual address
contract = w3.eth.contract(address=contract_address, abi=contract_abi)

# Connect to IPFS
ipfs_client = ipfshttpclient.connect('/ip4/127.0.0.1/tcp/5001')

# Mock database for users
users_db = {}

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data['username']
    password = data['password']
    if username in users_db:
        return jsonify({"msg": "Username already exists"}), 400
    users_db[username] = {
        "password": generate_password_hash(password),
        "ethereum_address": data['ethereum_address']
    }
    return jsonify({"msg": "User registered successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data['username']
    password = data['password']
    if username not in users_db or not check_password_hash(users_db[username]['password'], password):
        return jsonify({"msg": "Bad username or password"}), 401
    access_token = create_access_token(identity=username)
    return jsonify(access_token=access_token), 200

@app.route('/mint_nft', methods=['POST'])
@jwt_required()
def mint_nft():
    try:
        current_user = get_jwt_identity()
        data = request.json
        athlete_name = data['athlete_name']
        item_description = data['item_description']
        event_date = data['event_date']
        rarity = data['rarity']
        
        # Create metadata
        metadata = {
            "name": f"{athlete_name} Memorabilia",
            "description": item_description,
            "athlete": athlete_name,
            "event_date": event_date,
            "rarity": rarity,
            "minted_date": datetime.now().isoformat(),
            "minted_by": current_user
        }
        
        # Upload metadata to IPFS
        ipfs_hash = ipfs_client.add_json(metadata)
        metadata_uri = f"ipfs://{ipfs_hash}"
        
        # Call the smart contract function to mint the NFT
        owner_address = users_db[current_user]['ethereum_address']
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
@jwt_required()
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
@jwt_required()
def transfer_nft():
    try:
        current_user = get_jwt_identity()
        data = request.json
        to_address = data['to_address']
        token_id = data['token_id']
        
        from_address = users_db[current_user]['ethereum_address']
        
        tx_hash = contract.functions.transferFrom(from_address, to_address, token_id).transact()
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        return jsonify({
            "success": True,
            "transaction_hash": receipt.transactionHash.hex()
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/my_nfts', methods=['GET'])
@jwt_required()
def my_nfts():
    current_user = get_jwt_identity()
    user_address = users_db[current_user]['ethereum_address']
    
    # This is a simplified version. In a real-world scenario, you'd need to implement pagination
    # and more efficient querying, possibly using events or a separate database.
    owned_tokens = []
    last_token_id = contract.functions.getLastTokenId().call()
    
    for token_id in range(1, last_token_id + 1):
        if contract.functions.ownerOf(token_id).call() == user_address:
            owned_tokens.append(token_id)
    
    return jsonify({"owned_tokens": owned_tokens})

if __name__ == '__main__':
    app.run(debug=True)

# File: smart_contract.clar
(define-non-fungible-token sports-nft uint)

(define-data-var last-token-id uint u0)

(define-map token-metadata uint (string-utf8 256))

(define-public (mint-nft (metadata-uri (string-utf8 256)) (recipient principal))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    (try! (nft-mint? sports-nft token-id recipient))
    (map-set token-metadata token-id metadata-uri)
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
  (ok (map-get? token-metadata token-id))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? sports-nft token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

# File: templates/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sports Memorabilia NFT Marketplace</title>
    <script src="https://cdn.jsdelivr.net/npm/web3@1.5.2/dist/web3.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
</head>
<body>
    <h1>Sports Memorabilia NFT Marketplace</h1>
    <div id="auth-section">
        <h2>Authentication</h2>
        <input type="text" id="username" placeholder="Username">
        <input type="password" id="password" placeholder="Password">
        <input type="text" id="ethereum-address" placeholder="Ethereum Address">
        <button onclick="register()">Register</button>
        <button onclick="login()">Login</button>
    </div>
    <div id="nft-section" style="display:none;">
        <h2>Mint New NFT</h2>
        <input type="text" id="athlete-name" placeholder="Athlete Name">
        <input type="text" id="item-description" placeholder="Item Description">
        <input type="date" id="event-date">
        <select id="rarity">
            <option value="common">Common</option>
            <option value="rare">Rare</option>
            <option value="legendary">Legendary</option>
        </select>
        <button onclick="mintNFT()">Mint NFT</button>
        <h2>My NFTs</h2>
        <div id="my-nfts"></div>
    </div>
    <script>
        let accessToken = '';

        async function register() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const ethereumAddress = document.getElementById('ethereum-address').value;
            try {
                const response = await axios.post('/register', { username, password, ethereum_address: ethereumAddress });
                alert(response.data.msg);
            } catch (error) {
                alert(error.response.data.msg);
            }
        }

        async function login() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            try {
                const response = await axios.post('/login', { username, password });
                accessToken = response.data.access_token;
                document.getElementById('auth-section').style.display = 'none';
                document.getElementById('nft-section').style.display = 'block';
                fetchMyNFTs();
            } catch (error) {
                alert(error.response.data.msg);
            }
        }

        async function mintNFT() {
            const athleteName = document.getElementById('athlete-name').value;
            const itemDescription = document.getElementById('item-description').value;
            const eventDate = document.getElementById('event-date').value;
            const rarity = document.getElementById('rarity').value;
            try {
                const response = await axios.post('/mint_nft', 
                    { athlete_name: athleteName, item_description: itemDescription, event_date: eventDate, rarity },
                    { headers: { 'Authorization': `Bearer ${accessToken}` } }
                );
                alert(`NFT minted successfully! Token ID: ${response.data.token_id}`);
                fetchMyNFTs();
            } catch (error) {
                alert(error.response.data.error);
            }
        }

        async function fetchMyNFTs() {
            try {
                const response = await axios.get('/my_nfts', 
                    { headers: { 'Authorization': `Bearer ${accessToken}` } }
                );
                const myNFTsDiv = document.getElementById('my-nfts');
                myNFTsDiv.innerHTML = '';
                for (const tokenId of response.data.owned_tokens) {
                    const nftDetails = await axios.get(`/get_nft/${tokenId}`, 
                        { headers: { 'Authorization': `Bearer ${accessToken}` } }
                    );
                    const nftDiv = document.createElement('div');
                    nftDiv.innerHTML = `
                        <h3>${nftDetails.data.metadata.name}</h3>
                        <p>Athlete: ${nftDetails.data.metadata.athlete}</p>
                        <p>Description: ${nftDetails.data.metadata.description}</p>
                        <p>Rarity: ${nftDetails.data.metadata.rarity}</p>
                        <p>Event Date: ${nftDetails.data.metadata.event_date}</p>
                    `;
                    myNFTsDiv.appendChild(nftDiv);
                }
            } catch (error) {
                console.error('Error fetching NFTs:', error);
            }
        }
    </script>
</body>
</html>

# File: requirements.txt
Flask==2.0.1
flask-jwt-extended==4.3.1
web3==5.23.0
ipfshttpclient==0.8.0
Werkzeug==2.0.1