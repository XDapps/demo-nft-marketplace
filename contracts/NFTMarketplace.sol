// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//******************** Demo NFT Marketplace ***********************/
// This is demo NFT marketplace contract for ERC-721 tokens.
// The contract allows users to post their NFTs for sale and buy NFTs.
//
// This contract is for demonstration purposes only and is not audited.
//******************************************************************/

contract NFTMarketplace is Ownable {
    //*********************** Storage Variables ***********************/
    uint public constant MAXFEE = 300;
    uint256 private _listingCounter;
    address private _feeCollector;
    uint256 private _feeBasisPoints;
    string public name;

    struct TokenListing {
        address owner;
        address tokenAddress;
        uint256 tokenId;
        address paymentToken;
        uint256 askingPrice;
    }

    mapping(uint256 => TokenListing) public listings;
    //Boolean mapping from token address to listing ID. Returns 0 if not for sale.
    mapping(address => mapping(uint256 => uint256)) public tokenListingId;

    //*********************** Constructor ***********************/
    constructor(string memory _name, address _collector, uint256 _fee) Ownable(msg.sender) {
        require(_fee <= MAXFEE, "Error: Fee must be less than 3%");
        name = _name;
        _feeCollector = _collector;
        _feeBasisPoints = _fee;
    }

    //*********************** Events ***********************/
    event ListingAdded(
        uint256 indexed id,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 askingPrice
    );
    event ListingPriceChanged(
        uint256 indexed id,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 askingPrice
    );
    event ListingRemoved(uint256 indexed id, address tokenAddress, uint256 tokenId);
    event ListingSold(
        uint256 indexed id,
        address indexed buyer,
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 salePrice
    );

    //*********************** Getters *************************/
    function getAskingPrice(address _tokenContract, uint256 _tokenId) public view returns (uint256) {
        uint256 listingId = tokenListingId[_tokenContract][_tokenId];
        return listings[listingId].askingPrice;
    }
    function getListingId(address _tokenAddress, uint256 _tokenId) public view returns (uint256) {
        return tokenListingId[_tokenAddress][_tokenId];
    }

    //*********************** Setters *************************/
    function setFeeCollector(address _collector) public onlyOwner {
        _feeCollector = _collector;
    }
    function setFeeBasisPoints(uint256 _fee) public onlyOwner {
        require(_fee <= MAXFEE, "Error: Fee must be less than 3%");
        _feeBasisPoints = _fee;
    }

    //*********************** List/Remove ***********************/
    function listItemForSale(
        address _tokenAddress,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _askingPrice
    ) external {
        require(_askingPrice > 0, "Error: Asking price must be greater than 0");
        require(!isForSale(_tokenAddress, _tokenId), "Error: Token is already for sale");
        require(_paymentTokenIsValid(_paymentToken), "Error: Invalid Payment Token");
        require(_isERC721Token(_tokenAddress), "Error: must be an ERC721 token");
        require(
            hasTransferApproval(msg.sender, _tokenAddress, _tokenId),
            "Error: must own the token and have transfer approval"
        );
        _listingCounter++;
        listings[_listingCounter] = TokenListing(msg.sender, _tokenAddress, _tokenId, _paymentToken, _askingPrice);
        tokenListingId[_tokenAddress][_tokenId] = _listingCounter;
        emit ListingAdded(_listingCounter, _tokenAddress, _tokenId, _paymentToken, _askingPrice);
    }
    function changePrice(address _tokenContract, uint256 _tokenId, address paymentToken, uint256 _newPrice) public {
        uint256 listingId = tokenListingId[_tokenContract][_tokenId];
        require(_newPrice > 0, "Error: Asking price must be greater than 0");
        require(msg.sender == listings[listingId].owner, "Error: must be the owner of the listing");
        require(
            hasTransferApproval(msg.sender, _tokenContract, _tokenId),
            "Error: must have transfer approval or be the owner"
        );
        require(_paymentTokenIsValid(paymentToken), "Error: Invalid Payment Token");
        listings[listingId].askingPrice = _newPrice;
        listings[listingId].paymentToken = paymentToken;
        emit ListingPriceChanged(listingId, _tokenContract, _tokenId, paymentToken, _newPrice);
    }
    function removeListing(address _tokenContract, uint256 _tokenId) public {
        uint256 listingId = tokenListingId[_tokenContract][_tokenId];
        address currentOwner = IERC721(_tokenContract).ownerOf(_tokenId);
        require(msg.sender == currentOwner, "Error: must be the owner of the token");
        listings[listingId].askingPrice = 0;
        tokenListingId[_tokenContract][_tokenId] = 0;
        emit ListingRemoved(listingId, _tokenContract, _tokenId);
    }
    //************************* Buy NFT *************************/
    function buyItem(address _tokenAddress, uint256 _tokenId, uint256 _expectedPrice) external payable {
        uint256 listingId = tokenListingId[_tokenAddress][_tokenId];
        require(listingId > 0, "Error: Token is not for sale");
        address owner = listings[listingId].owner;
        address tokenAddress = listings[listingId].tokenAddress;
        uint256 tokenId = listings[listingId].tokenId;
        address paymentToken = listings[listingId].paymentToken;
        uint256 askingPrice = listings[listingId].askingPrice;
        require(_expectedPrice >= askingPrice, "Error: Price Changed");
		require(msg.sender != owner, "Error: Buyer cannot be the owner of the token");
        require(hasTransferApproval(owner, tokenAddress, tokenId), "Error: owner revoked transfer approval.");
        //Remove Listing
        tokenListingId[tokenAddress][tokenId] = 0;
        listings[listingId].askingPrice = 0;
		//Handle Payments
        _transferPayments(owner, msg.sender, paymentToken, askingPrice);
        //Transfer NFT
        IERC721(tokenAddress).transferFrom(owner, msg.sender, tokenId);
        //Emit Event
        emit ListingSold(listingId, msg.sender, tokenAddress, tokenId, askingPrice);
    }
    //************************* Helpers *************************/
    function _transferPayments(address _seller, address _buyer, address _paymentToken, uint256 _amount) private {
		if (_paymentToken == address(0)) {
            _transferNativePayments(_seller, _amount);
        } else {
            _transferERC20Payments(_seller, _buyer, _paymentToken, _amount);
        }
    }
    function _transferERC20Payments(address _seller, address _buyer, address _paymentToken, uint256 _amount) private {
        uint256 fee = _calculateFee(_amount);
        IERC20 tokenContract = IERC20(_paymentToken);
        tokenContract.transferFrom(_buyer, _seller, _amount - fee);
        tokenContract.transferFrom(_buyer, _feeCollector, fee);
    }
    function _transferNativePayments(address _seller, uint256 _amount) private {
        uint256 fee = _calculateFee(_amount);
        require(msg.value >= _amount, "Error: Insufficient funds");
        bool paySeller = payable(_seller).send(_amount - fee);
        require(paySeller, "Error: Transfer to seller failed");
        bool payFeeCollector = payable(_feeCollector).send(fee);
        require(paySeller && payFeeCollector, "Error: Transfer failed");
    }
    function _calculateFee(uint256 _amount) private view returns (uint256) {
        return (_amount * _feeBasisPoints) / 10000;
    }
    function hasTransferApproval(
        address _ownerAddress,
        address _tokenContract,
        uint256 _tokenId
    ) public view returns (bool) {
        IERC721 tokenContract = IERC721(_tokenContract);
        bool isOwner = tokenContract.ownerOf(_tokenId) == _ownerAddress;
        bool hasApproval = tokenContract.getApproved(_tokenId) == address(this);
        bool approvedForAll = tokenContract.isApprovedForAll(_ownerAddress, address(this));
        return (isOwner && (hasApproval || approvedForAll));
    }
    function isForSale(address _tokenContract, uint256 _tokenId) public view returns (bool) {
        uint256 listingId = tokenListingId[_tokenContract][_tokenId];
        if (listingId == 0) {
            return false;
        }
        bool stillValid = hasTransferApproval(listings[listingId].owner, _tokenContract, _tokenId);
        return stillValid;
    }
    function _paymentTokenIsValid(address _paymentToken) private returns (bool) {
        if (_paymentToken == address(0)) {
            return true;
        }
        return _isERC20Token(_paymentToken);
    }
    function _isERC721Token(address addressToCheck) private view returns (bool) {
        bytes4 interfaceId = type(IERC721).interfaceId;
        IERC721 tokenContract = IERC721(addressToCheck);
        return tokenContract.supportsInterface(interfaceId);
    }

    function _isERC20Token(address addressToCheck) private returns (bool) {
        IERC20 tokenContract = IERC20(addressToCheck);

        // Using try-catch to verify contract implements these functions without reverting
        try tokenContract.totalSupply() returns (uint256) {} catch {
            return false;
        }
        try tokenContract.balanceOf(address(this)) returns (uint256) {} catch {
            return false;
        }
        try tokenContract.allowance(address(this), address(this)) returns (uint256) {} catch {
            return false;
        }
        // These function calls could revert if used improperly, so we use minimal values for checks
        try tokenContract.approve(address(this), 0) returns (bool) {} catch {
            return false;
        }
        try tokenContract.transfer(address(this), 0) returns (bool) {} catch {
            return false;
        }
        try tokenContract.transferFrom(address(this), address(this), 0) returns (bool) {} catch {
            return false;
        }

        // If all function calls are successful, then it's likely an ERC-20 token
        return true;
    }
}
