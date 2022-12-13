// // SPDX-License-identifier: MIT
// pragma solidity ^0.8.0;

// // import "@thirdweb-dev/contracts/base/ERC721Base.sol";

// import "@thirdweb-dev/contracts/openzeppelin-presets/token/ERC721/IERC721Receiver.sol";
// import "@thirdweb-dev/contracts/lib/TWAddress.sol";
// import "@thirdweb-dev/contracts/openzeppelin-presets/utils/Context.sol";
// import "@thirdweb-dev/contracts/lib/TWStrings.sol";
// import "@thirdweb-dev/contracts/eip/ERC165.sol";
// // import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";



// contract ERC721A is Context, ERC165, ERC721URIStorage {

//     using TWAddress for address;
//     using TWStrings for uint256;


//     error ApprovalCallerNotOwnerNorApproved();

//     error ApprovalQueryForNonexistentToken();

//     error ApproveToCaller();

//     error ApprovalToCurrentOwner();

//     error BalanceQueryForZeroAddress();

//     error MintToZeroAddress();

//     error MintZeroQuantity();

//     error OwnerQueryForNonexistentToken();

//     error TransferCallerNotOwnerNorApproved();

//     error TransferFromIncorrectOwner();

//     error TransferToNonERC721ReceiverImplementer();

//     error TransferToZeroAddress();

//     error URIQueryForNonexistentToken();

//     error SenderOrReceiverIsContract();

//     event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);


//     event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);


//     event ApprovalForAll(address indexed owner, address indexed operator, bool approved);



//     uint256 internal _currentIndex;

//     uint256 internal _burnCounter;

//     string private _name;
    
//     string private _symbol;


//     // Compiler will pack this into a single 256bit word.


//     mapping(uint256 => TokenOwnership) internal _ownerships;

//     mapping(address => AddressData) internal _addressData;

//     mapping(uint256 => address) private _tokenApprovals;

//     mapping(address => mapping(address => bool)) private _operatorApprovals;

//     mapping(uint256 => mapping(address => address)) internal ownerReceiver;


//     constructor(string memory name_, string memory symbol_) {
//         _name = name_;
//         _symbol = symbol_;
//         _currentIndex = _startTokenId();
//     }
//     function _startTokenId() internal view virtual returns (uint256) {
//         return 0;
//     }

//     function totalSupply() public view returns (uint256) {
//         unchecked {
//             return _currentIndex - _burnCounter - _startTokenId();
//         }
//     }
//     function _totalMinted() internal view returns (uint256) {

//         unchecked {
//             return _currentIndex - _startTokenId();
//         }
//     }


//     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     function balanceOf(address owner) public view returns (uint256) {
//         if (owner == address(0)) revert BalanceQueryForZeroAddress();
//         return uint256(_addressData[owner].balance);
//     }

//     function _numberMinted(address owner) internal view returns (uint256) {
//         return uint256(_addressData[owner].numberMinted);
//     }

//     function _numberBurned(address owner) internal view returns (uint256) {
//         return uint256(_addressData[owner].numberBurned);
//     }

//     function _numberPurchased(address owner) internal view returns (uint64) {
//         return _addressData[owner].purchased;
//     }
//     function _numberSold(address owner) internal view returns (uint256) {
//         return uint256(_addressData[owner].sold);
//     }

//     function _ownershipOf(uint256 tokenId) internal view returns (TokenOwnership memory) {
//         uint256 curr = tokenId;

//         unchecked {
//             if (_startTokenId() <= curr)
//                 if (curr < _currentIndex) {
//                     TokenOwnership memory ownership = _ownerships[curr];
//                     if (!ownership.burned) {
//                         if (ownership.addr != address(0)) {
//                             return ownership;
//                         }
//                         while (true) {
//                             curr--;
//                             ownership = _ownerships[curr];
//                             if (ownership.addr != address(0)) {
//                                 return ownership;
//                             }
//                         }
//                     }
//                 }
//         }
//         revert OwnerQueryForNonexistentToken();
//     }

//     function ownerOf(uint256 tokenId) public view returns (address) {
//         return _ownershipOf(tokenId).addr;
//     }


//     function name() public view virtual returns (string memory) {
//         return _name;
//     }


//     function symbol() public view virtual returns (string memory) {
//         return _symbol;
//     }


//     function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
//         if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

//         string memory baseURI = _baseURI();
//         return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
//     }


//     function _baseURI() internal view virtual returns (string memory) {
//         return "";
//     }


//     function approve(address to, uint256 tokenId) public {
//         address owner = ERC721A.ownerOf(tokenId);
//         if (to == owner) revert ApprovalToCurrentOwner();

//         if (_msgSender() != owner)
//             if (!isApprovedForAll(owner, _msgSender())) {
//                 revert ApprovalCallerNotOwnerNorApproved();
//             }

//         _approve(to, tokenId, owner);
//     }


//     function getApproved(uint256 tokenId) public view returns (address) {
//         if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

//         return _tokenApprovals[tokenId];
//     }


//     function setApprovalForAll(address operator, bool approved) public virtual {
//         if (operator == _msgSender()) revert ApproveToCaller();

//         _operatorApprovals[_msgSender()][operator] = approved;
//         emit ApprovalForAll(_msgSender(), operator, approved);
//     }

//     function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
//         return _operatorApprovals[owner][operator];
//     }


//     function transferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public virtual {
//         _transfer(from, to, tokenId);
//     }


//     function _exists(uint256 tokenId) internal view returns (bool) {
//         return _startTokenId() <= tokenId && tokenId < _currentIndex && !_ownerships[tokenId].burned;
//     }



//     function _mint(
//         address to,
//         address receiver, 
//         bytes memory tokenURI
//     ) internal {
//         if (to.isContract() || receiver.isContract()) {
//                revert SenderOrReceiverIsContract();
//         }

//         uint256 startTokenId = _currentIndex;
//         if (to == address(0)) revert MintToZeroAddress();
//         if (quantity == 0) revert MintZeroQuantity();

//         _beforeTokenTransfers(address(0), to, startTokenId, quantity);


//         unchecked {
//             _addressData[to].balance += 1;
//             _addressData[to].numberMinted += 1;

//             _ownerships[startTokenId].addr = to;
//             _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);
//             ownerReceiver[startTokenId][to] = receiver;
//             _setTokenURI(startTokenId, tokenURI); //TODO


//             uint256 updatedIndex = startTokenId;
//             uint256 end = updatedIndex + quantity;

//             do {
//                 emit Transfer(address(0), to, updatedIndex++);
//             } while (updatedIndex < end);

//             _currentIndex = updatedIndex;
//         }
//         _afterTokenTransfers(address(0), to, startTokenId, quantity);
//     }

//     function _transfer(
//         address from,
//         address to,
//         uint256 tokenId
//     ) private {
//         TokenOwnership memory prevOwnership = _ownershipOf(tokenId);

//         if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();

//         bool isApprovedOrOwner = (_msgSender() == from ||
//             isApprovedForAll(from, _msgSender()) ||
//             getApproved(tokenId) == _msgSender());

//         if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
//         if (to == address(0)) revert TransferToZeroAddress();

//         _beforeTokenTransfers(from, to, tokenId, 1);


//         _approve(address(0), tokenId, from);


//         unchecked {
//             _addressData[from].balance -= 1;
//             _addressData[to].balance += 1;

//             TokenOwnership storage currSlot = _ownerships[tokenId];
//             currSlot.addr = to;
//             currSlot.startTimestamp = uint64(block.timestamp);


//             uint256 nextTokenId = tokenId + 1;
//             TokenOwnership storage nextSlot = _ownerships[nextTokenId];
//             if (nextSlot.addr == address(0)) {

//                 if (nextTokenId != _currentIndex) {
//                     nextSlot.addr = from;
//                     nextSlot.startTimestamp = prevOwnership.startTimestamp;
//                 }
//             }
//         }

//         emit Transfer(from, to, tokenId);
//         _afterTokenTransfers(from, to, tokenId, 1);
//     }

//     function _burn(uint256 tokenId) internal virtual {
//         _burn(tokenId, false);
//     }

//     function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
//         TokenOwnership memory prevOwnership = _ownershipOf(tokenId);

//         address from = prevOwnership.addr;

//         if (approvalCheck) {
//             bool isApprovedOrOwner = (_msgSender() == from ||
//                 isApprovedForAll(from, _msgSender()) ||
//                 getApproved(tokenId) == _msgSender());

//             if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
//         }

//         _beforeTokenTransfers(from, address(0), tokenId, 1);

//         _approve(address(0), tokenId, from);


//         unchecked {
//             AddressData storage addressData = _addressData[from];
//             addressData.balance -= 1;
//             addressData.numberBurned += 1;

//             TokenOwnership storage currSlot = _ownerships[tokenId];
//             currSlot.addr = from;
//             currSlot.startTimestamp = uint64(block.timestamp);
//             currSlot.burned = true;

//             uint256 nextTokenId = tokenId + 1;
//             TokenOwnership storage nextSlot = _ownerships[nextTokenId];
//             if (nextSlot.addr == address(0)) {

//                 if (nextTokenId != _currentIndex) {
//                     nextSlot.addr = from;
//                     nextSlot.startTimestamp = prevOwnership.startTimestamp;
//                 }
//             }
//         }

//         emit Transfer(from, address(0), tokenId);
//         _afterTokenTransfers(from, address(0), tokenId, 1);

//         unchecked {
//             _burnCounter++;
//         }
//     }

//     function _approve(
//         address to,
//         uint256 tokenId,
//         address owner
//     ) private {
//         _tokenApprovals[tokenId] = to;
//         emit Approval(owner, to, tokenId);
//     }


//     function _beforeTokenTransfers(
//         address from,
//         address to,
//         uint256 startTokenId,
//         uint256 quantity
//     ) internal virtual {}

//     function _afterTokenTransfers(
//         address from,
//         address to,
//         uint256 startTokenId,
//         uint256 quantity
//     ) internal virtual {}
// }

