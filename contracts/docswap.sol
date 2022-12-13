// SPDX-License-identifier: MIT
pragma solidity ^0.8.9;

/*
    This contract works as an insurance policy for two people exchanging money for a doc(a signed paper, ticket, or a release);
    The task of this contract is to allow a user to upload a doc select a buyer select a timeframe to have the transaction and select the asking
    price
    if the buyer does not offer the money within the specific timeFrame the user can take their document back if they want
    first trade is free between the two party else this contract collects a percentage from both buyer and seller.



*/
import "./ERC721A.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";


contract docSwap is
    Initializable,
    ReentrancyGuardUpgradeable,
    ContextUpgradeable,
    MulticallUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721A
     {
         //I dont think i need multicall, look into ERC2771 trusted forwarders

    uint256 public totalListings;

    string public contractURI;

    address private platformFeeRecipient;

    uint64 public  MAX_BPS = 1000;

    uint64 private  platformFeeBps = 25;

    address payable owner;

    address private immutable assetContract;



    struct DocSwapList {
        uint256 tokenId;
        uint256 listingId;
        address payable from;
        address to;
        uint256 askingPrice;
        uint256 timeFrame;
        bool active;
        address assetContract;
    }

    struct SaleData {
        uint64 purchased;

        uint64 sold;
    }


    event ListingAdded(
        uint256 indexed listingId,
        address indexed from,
        address indexed to,
        uint256 askingPrice,
        uint256 timeFrame
    );

    event ListingRemoved(
        uint256 indexed listingId,
        address indexed listingCreator
    );

    event NewSale (
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 amount); //TODO


    mapping(uint256 => DocSwapList) internal docSwapLists; //listingId => docswapinfo

    mapping(address => SaleData) private _saleData;


    receive() external payable {}



    constructor(
        string memory _name,
        string memory _symbol,
        address _assetContract,
        string memory _contractURI
        ) ERC721A(_name,_symbol, address(this)) {
        owner = payable(_msgSender());
        assetContract =  _assetContract;

         __ReentrancyGuard_init();

         contractURI = _contractURI;

    }


    modifier onlyExistingListing(uint256 _listingId) {
        require(docSwapLists[_listingId].assetContract != address(0), "DNE");
        _;
    }
    modifier onlyListingCreator(uint256 _listingId) {
        require(docSwapLists[_listingId].from == _msgSender(), "!OWNER");
        _;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721A)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId ||
            interfaceId == type(IERC721ReceiverUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }



    function createListing(address payable to, address receiver, uint256 askingPrice, uint256 timeFrame, string memory tokenURI) external returns (bool){
        uint256 listingId = totalListings;
        totalListings += 1;
        address tokenOwner = _msgSender();

        if( to == receiver) {
            revert();
        }
        if(timeFrame <= 0) {
            revert();
        }
        uint256 tokenId = docSwapMint(to, receiver, tokenURI);


        unchecked {
             timeFrame = timeFrame + block.timestamp;
        }

        validateOwnershipAndApproval(
            to,
            address(this),
            tokenId
        );

        DocSwapList memory currDocSwapList =  DocSwapList({
            tokenId : tokenId, //TODO double check that this is the same as lisitng id
            listingId : listingId,
            from : to,
            to : receiver,
            askingPrice : askingPrice,
            timeFrame : timeFrame,
            active: true,
            assetContract: address(this) //TODO how are you gonna fetch address
      });

        docSwapLists[listingId] = currDocSwapList;

        emit ListingAdded (
            listingId,
            to,
            receiver,
            askingPrice,
            timeFrame); //TODO

        return true;

    }

    function buy(uint256 listingId) external payable nonReentrant onlyExistingListing(listingId) {
        address buyer = _msgSender ();

        DocSwapList memory listing = docSwapLists[listingId];

        uint256 timeFrame = listing.timeFrame;


        if(buyer != tx.origin) {
            revert("DocSwap: Only wallets can call");
        }


        if(_msgSender() != listing.to) {
            revert ("DocSwap: only a specific address can purchase this");

        }
        if(timeFrame < block.timestamp) {
            revert("DocSwap: You can't purchase this document outised the owners lisitng TimeFrame");
        }
        executeSale(listingId);

        docSwapLists[listingId].to = address(0);
        docSwapLists[listingId].active = false;

        emit NewSale(
            listing.tokenId,
            listing.from,
            listing.to,
            listing.askingPrice
        );
    }

    function cancelListing(uint256 listingId) public {
        DocSwapList memory listing = docSwapLists[listingId];
        address lister = listing.from;
        uint256 timeFrame = listing.timeFrame;


        if(_msgSender() != lister) {
            revert ("DocSwap: Only lister can cancel the listing");
        }
        if(timeFrame > block.timestamp) {
            revert("DocSwap: You can not cancel the lisitng until the time period you set has passed");
        }

        delete docSwapLists[listingId];

        _burn(listing.tokenId, true); // TODO  just cancel listing and return token

        // let burn be its own seperste function

    }

    function executeSale(uint256 listingId) private {
        DocSwapList memory list = docSwapLists[listingId];


        validateOwnershipAndApproval(
            list.from,
            list.assetContract,
            list.tokenId
        );

        callculateFees(listingId);

        address seller = list.from;
        address buyer =  list.to;

        transferListingToken(
            seller,
            buyer,
            list
        );
        _saleData[seller].sold += 1;
        _saleData[buyer].purchased += 1;
    }

    function callculateFees(uint256 listingId) private {

        /* if this the first time for the buyer or the seller then
        it is free they would only have to pay for gas

        */

        DocSwapList memory currList = docSwapLists[listingId];

        address payable seller = currList.from;
        address buyer =  currList.to;

        uint256 askingAmount = currList.askingPrice;


        (bool freebieSeller, bool freebieBuyer) = checkFreebie(seller, buyer);

        (uint256 sellerFees, uint256 buyerFees, uint256 halfMarketFee) = docSwapFees(askingAmount);

        if(freebieBuyer) {
            uint256 buyerFinalAmount = askingAmount;
            if(msg.value != (buyerFinalAmount)) {
                revert("DocSwap: submitted amount is not the same as requested amount");
            }

        }
        if(!freebieBuyer) {
            uint256 buyerFinalAmount = askingAmount + buyerFees;
            if(msg.value != (buyerFinalAmount)) {
                revert("DocSwap: submitted amount is not the same as requested amount + marketFees");
            }
            require(halfMarketFee <= address(this).balance, "Not enough funds to withdrawal");
            owner.transfer(halfMarketFee);
        }

        if(freebieSeller) {
            seller.transfer(askingAmount);
        }


        if(!freebieSeller) {
            uint256 sellerFinalAmount = askingAmount - sellerFees;
            require(sellerFinalAmount <= address(this).balance, "Not enough funds to withdrawal");
            require(halfMarketFee <= address(this).balance, "Not enough funds to withdrawal");

            seller.transfer(sellerFinalAmount);
            owner.transfer(halfMarketFee);
        }



    }

    function docSwapFees(uint256 totalAmount) private view returns (uint256 sellerFees, uint256 buyerFees, uint256 halfMarketFee){
        /*
        docSwapCharges a 2.5 percent from seller, and 2.5 percent from buyer

        */
        uint256 halfMarketFee;

        unchecked {

         halfMarketFee = totalAmount - ((totalAmount * platformFeeBps) / MAX_BPS);
        }
        sellerFees = halfMarketFee;
        buyerFees = halfMarketFee;

        return (sellerFees, buyerFees, halfMarketFee);

    }

    function checkFreebie(address seller, address buyer) private view returns (bool freebieSeller, bool freebieBuyer){
        uint256 numberSoldSeller = _saleData[seller].sold;
        uint256 numberPurchasedSeller = _saleData[seller].purchased;

        uint256 numberSoldBuyer = _saleData[buyer].sold;
        uint256 numberPurchasedBuyer = _saleData[buyer].purchased;

        if(numberSoldSeller < 1) {
            if(numberPurchasedSeller < 1) {
             freebieSeller = true;
            }
        }

        if(numberSoldBuyer < 1) {
            if(numberPurchasedBuyer < 1) {

             freebieBuyer = true;
            }
        }

        return (freebieSeller, freebieBuyer);
    }


    function transferListingToken(
        address from,
        address to,
        DocSwapList memory list
    ) internal {
         IERC721Upgradeable(list.assetContract).safeTransferFrom(from, to, list.tokenId, "");
    }

    function updateListing(
        uint256 listingId,
        address to,
        uint256 askingAmount,
        uint256 timeFrame
    ) internal onlyListingCreator(listingId){
        DocSwapList storage list = docSwapLists[listingId];

        require(_msgSender() == ownerOf(list.tokenId));

        list.to = to;
        list.askingPrice = askingAmount;
        list.timeFrame = timeFrame + block.timestamp;

    }

// ############################################## I need to check below this line

    function validateOwnershipAndApproval(
        address _tokenOwner,
        address _assetContract,
        uint256 _tokenId
        ) internal view {
        address market = address(this);
        bool isValid;

         isValid =
                IERC721Upgradeable(_assetContract).ownerOf(_tokenId) == _tokenOwner &&
                (IERC721Upgradeable(_assetContract).getApproved(_tokenId) == market ||
                    IERC721Upgradeable(_assetContract).isApprovedForAll(_tokenOwner, market));

        require(isValid, "notValid");
    }



    function setContractURI(string calldata _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contractURI = _uri;
    }

    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (platformFeeRecipient, uint16(platformFeeBps));
    }

    function setPlatformFeeInfo(address _platformFeeRecipient, uint256 _platformFeeBps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_platformFeeBps <= MAX_BPS, "bps <= 10000");

        platformFeeBps = uint64(_platformFeeBps);
        platformFeeRecipient = _platformFeeRecipient;

      //  emit PlatformFeeInfoUpdated(_platformFeeRecipient, _platformFeeBps); TODO this needs work
    }
    function _numberPurchased(address owner) internal view returns (uint64) {
        return _saleData[owner].purchased;
    }
    function _numberSold(address owner) internal view returns (uint256) {
        return uint256(_saleData[owner].sold);
    }


    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable)
        returns (address sender)
    {
        return ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable)
        returns (bytes calldata)
    {
        return ContextUpgradeable._msgData();
    }

   function userDocuments() public view returns(DocSwapList[] memory) {
     uint256 totalItemCount = totalListings;
     uint256 itemCount = 0;
     uint256 currentIndex = 0;

     for (uint256 i =0; i < totalItemCount; i++) {
       if(docSwapLists[i+1].from == _msgSender()) {
         itemCount += 1;
       }

     }
     DocSwapList[] memory items = new DocSwapList[](itemCount);
     for(uint256 i = 0; i < totalItemCount; i++) {
       if(docSwapLists[i+1].from == _msgSender()) {
         DocSwapList storage currentItem = docSwapLists[i+1];
         items[currentIndex] = currentItem;
         currentIndex += 1;
       }
     }
     return items;
   }

   function buyerDocuments() public view returns(DocSwapList[] memory) {
     uint256 totalItemCount = totalListings;
     uint256 itemCount = 0;
     uint256 currentIndex = 0;

     for (uint256 i =0; i < totalItemCount; i++) {
       if(docSwapLists[i+1].to == _msgSender()) {
         itemCount += 1;
       }

     }
     DocSwapList[] memory items = new DocSwapList[](itemCount);
     for(uint256 i = 0; i < totalItemCount; i++) {
       if(docSwapLists[i+1].to == _msgSender()) {
         DocSwapList storage currentItem = docSwapLists[i+1];
         items[currentIndex] = currentItem;
         currentIndex += 1;
       }
     }
     return items;
   }


 /*
function i need to add are view function, fetch all document that are owned by one party, and show it to them,
fetch the total number of swaps that have been done so far,
fetch all documents in the app to show to owner,
make sure that no one can use the contract address and get a tokenId to get tehm the item they are looking for,
see if i need to add a bool for blurring
*/

}
