Sports Memorabilia NFT Project

This project implements a blockchain-based system for creating and managing Non-Fungible Tokens (NFTs) representing sports memorabilia and collectibles. It uses Python for the backend, Flask for the API, and Clarity (Stacks) for the smart contract.
Features

Mint new NFTs for sports memorabilia
Retrieve NFT details
Smart contract for NFT management on the Stacks blockchain

Prerequisites

Python 3.7+
Node.js and npm (for Clarity contract deployment)
Access to a Stacks blockchain node (local or testnet)

Installation

Clone the repository:
Copygit clone https://github.com/Midorichie/sports-memorabilia-nft.git
cd sports-memorabilia-nft

Install Python dependencies:
Copypip install -r requirements.txt

Install Clarity CLI (for smart contract deployment):
Copynpm install -g @stacks/cli


Smart Contract Deployment

Configure your Stacks account in the Clarity CLI.
Deploy the smart contract:
Copyclarity deploy smart_contract.clar

Note the contract address after deployment and update it in app.py.

Running the Application

Start the Flask application:
Copypython app.py

The API will be available at http://localhost:5000.

API Endpoints

POST /mint_nft: Mint a new NFT

Request body: { "token_id": int, "metadata_uri": string, "owner_address": string }
Response: { "success": bool, "transaction_hash": string }


GET /get_nft/<token_id>: Get NFT details

Response: { "token_id": int, "owner": string, "metadata_uri": string }



Future Improvements

Implement authentication and authorization
Add more sports-specific features (e.g., athlete signatures, event metadata)
Integrate with IPFS for decentralized metadata storage
Implement a frontend interface for easier interaction

Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
License
This project is licensed under the MIT License.