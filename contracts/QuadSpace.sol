// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";
//  dependencies injected for royalties configuration   
import "./RoyaltiesV2Impl.sol";
import "./LibPart.sol";
import "./LibRoyaltiesV2.sol";

contract TMDW is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ERC721Burnable, ERC721Pausable, RoyaltiesV2Impl {

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    //globals
    Counters.Counter private _tokenIdTracker;
    bool public saleOpen = false;
    uint256 private _price;
    uint256 private _maxQuads;
    uint256 private _maxMint;
    uint96 private _royaltyBPS;
    bool public canMintCenter = false;
    bool public canMintSpecial = false;
    bool public lockFreestyle = true;
    bool public transferable = false;
    uint256[] private _occupiedList;
    uint public parcelCount;
    bool private _isPresale;
    string private baseTokenURI;
    string public _defaultContentBaseURI;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    uint256 public constant QUAD_COLUMNS = 1000;
    uint256 public constant QUAD_ROWS = 1000;
    uint256 private constant MAX_QUADS = QUAD_COLUMNS * QUAD_COLUMNS; 
    uint256 private constant MAX_MINT = QUAD_COLUMNS * QUAD_COLUMNS; 
    struct Parcel { uint coord; uint width; uint height; address owner; string uri;}

    //data
    mapping(uint256=>Parcel) public parcels;
    mapping(address => bool) public _whitelist;
    mapping(uint256 => string) private _tokenContentURIs;
    mapping(uint256 => bool) private _isOccupiedId;
    

    //events

    event QuadMint(address to, uint256 indexed id);
    event NewParcel(address to, uint256 indexed id);
    event TokenContentURIChanged(uint256 indexed tokenId);
    event ParcelUpdated(address to, uint256 indexed id);

    constructor (string memory baseURI) ERC721("THE MILLION DOLLAR WEBSITE", "TMDW") {
         setBaseURI(baseURI);
        _maxQuads = MAX_QUADS;
        _maxMint = MAX_QUADS;
        _royaltyBPS = 1000;
         parcelCount = 0;
    }

    //  modifiers
    modifier saleIsOpen {
        if (_msgSender() != owner()) {
            require(saleOpen == true, "SALES: Please wait a big longer before buying Quads ;)");
        }
        require(_totalSupply() <= MAX_QUADS, "SALES: Sale end");

        if (_msgSender() != owner()) {
            require(!paused(), "PAUSABLE: Paused");
        }
        _;
    }

    modifier onlyValidGroup(uint256 tokenId, uint256 width, uint256 height) {
        require(width > 0, " width must be > 0");
        require(height > 0, " height must be > 0");
        _;
    }

    modifier onlyQuadOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == _msgSender(), "caller is not the tokenOwner");
        _;
    }

    modifier onlyTotalQuadsOwner(uint256 tokenId, uint256 width, uint256 height) {
        for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                require(ownerOf(innerTokenId) == _msgSender(), "MDTP: caller is not the tokenOwner of all tokens in group");
            }
        }
        _;
    }

    // utils

     function isAnyInMiddle(uint256 tokenId, uint256 width, uint256 height) internal pure returns (bool) {
        for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                if (isInMiddle(innerTokenId)) {
                    return true;
                }
            }
        }

        return false;
    }

    function isAnyASpecialQuad(uint256 tokenId, uint256 width, uint256 height) internal pure returns (bool) {
        for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                if (isInSpecial(innerTokenId)) {
                    return true;
                }
            }
        }
        return false;
    }

   function isInMiddle(uint256 tokenId) internal pure returns (bool) {
        uint256 x = tokenId % QUAD_COLUMNS;
        uint256 y = tokenId / QUAD_ROWS;
        return x >= 376 && x <= 625 && y >= 401 && y <= 600;
    }

    function isInSpecial(uint256 tokenId) internal pure returns (bool) {
        uint256 x = tokenId % QUAD_COLUMNS;
        uint256 y = tokenId / QUAD_ROWS;

        bool specialA = x >= 1 && x <= 250 && y >= 1 && y <= 200;
        bool specialB = x >= 751 && x <= 1000 && y >= 1 && y <= 200;
        bool specialC = x >= 1 && x <= 250 && y >= 801 && y <= 1000;
        bool specialD = x >= 751 && x <= 1000 && y >= 801 && y <= 1000;

        if(specialA || specialB || specialC || specialD){
          return true;
        }else{
            return false;
        }
    }

    //user interactions
    function mint(address payable _to, uint256 tokenId, uint256 width, uint256 height, string memory parcelUri) public payable saleIsOpen onlyValidGroup(tokenId, width, height) {
        uint256 total = _totalSupply();
        uint256 totalMints = width * height;

        require(total <= _maxQuads, "MINT: Please go to the Opensea to buy a quad.");
        require(totalMints > 0, "insufficient quantity");
        require(canMintCenter || !isAnyInMiddle(tokenId, width, height), "Cannot mint center tokens");
        require(canMintSpecial || !isAnyASpecialQuad(tokenId, width, height), "MintCannot mint special tokens");
        
        if (_to != owner()) {
            require(msg.value >= price(totalMints), "MINT: Current value is below the sales price of a quad");
        }

         for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
               require(_isOccupiedId[innerTokenId] == false, "MINT: Those quads already have been claimed");
            }
        }
        
         for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                _mintAQuad(_to, innerTokenId);
            }
        }

            _createParcel(_to, tokenId, width, height, parcelUri);

    }

    function _createParcel(address  _to, uint256 tokenId, uint256 width, uint256 height, string memory parcelUri) private {
         parcels[parcelCount + 1] = (Parcel(tokenId, width, height, _to, parcelUri));
         parcelCount  = parcelCount + 1;

         emit NewParcel(_to, tokenId);
    }

    function _mintAQuad(address payable _to, uint256 _id) private {
     require(_id > 0 && _id <= MAX_QUADS, "invalid tokenId");

        address addr = owner();
        address payable wallet = payable(addr);

        _tokenIdTracker.increment();
        _safeMint(_to, _id);
        _isOccupiedId[_id] = true;
        _occupiedList.push(_id);
        setInitialRoyalties(_id, wallet);
        emit QuadMint(_to, _id);
    }

     function updateParcelData(uint256 parcelId, uint256 parcelCoord, uint256 width, uint256 height, string memory parcelUri) public onlyTotalQuadsOwner(parcelCoord, width, height){
   
        require(lockFreestyle == true , "Cannot edit on freestyle mode at the moment. use different update method");

        uint256 prevWidth = parcels[parcelId].width;
        uint256 prevHeight = parcels[parcelId].height;
        uint256 x = parcelCoord % QUAD_COLUMNS;
        uint256 y = parcelCoord / QUAD_ROWS;
        
        if(prevWidth == width && prevHeight == height){
            parcels[parcelId] = (Parcel(parcelCoord, width, height, _msgSender(), parcelUri));
         }else{
             
             _createParcel(_msgSender(), parcelCoord, width, height, parcelUri);

            if(prevWidth == width){
                if(parcels[parcelId].coord/1000 == y){
                    parcels[parcelId] = (Parcel(parcelCoord + (1000 * height), width, prevHeight - height, _msgSender(), parcelUri));
                }else{
                    parcels[parcelId] = (Parcel(parcels[parcelId].coord, width, prevHeight - height, _msgSender(), parcelUri));
                }
                
            }
            if(prevHeight == height){             
                if(parcels[parcelId].coord % 1000 == x){
                    parcels[parcelId] = (Parcel(parcelCoord + width, prevWidth - width, height, _msgSender(), parcelUri));
                }else{
                    parcels[parcelId] = (Parcel(parcels[parcelId].coord, prevWidth - width, height, _msgSender(), parcelUri));
                }  
                   
            }

            if(prevHeight != height && prevWidth != width){
                    if(parcelCoord == parcels[parcelId].coord){
                         parcels[parcelId] = (Parcel(parcelCoord + width, prevWidth - width, height, _msgSender(), parcelUri));
                        _createParcel(_msgSender(), parcelCoord + (1000 * height), prevWidth, prevHeight - height, parcelUri);
                    }
            }

         }

        emit ParcelUpdated(_msgSender(), parcelId);
    }

    function _setTokenContentURI(uint256 tokenId, string memory contentURI) internal {
        _tokenContentURIs[tokenId] = contentURI;
        emit TokenContentURIChanged(tokenId);
    }

    function setTokenContentURI(uint256 tokenId, string memory contentURI) public onlyQuadOwner(tokenId) {
        _setTokenContentURI(tokenId, contentURI);
    }

    function setTokenGroupContentURIs(uint256 tokenId, uint256 width, uint256 height, string[] memory contentURIs) public onlyTotalQuadsOwner(tokenId, width, height) onlyValidGroup(tokenId, width, height) {
        require(width * height == contentURIs.length, "length of contentURIs must be the same as width * height");
        for (uint256 y = 0; y < height; y++) {
            for (uint256 x = 0; x < width; x++) {
                uint256 index = (width * y) + x;
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                _setTokenContentURI(innerTokenId, contentURIs[index]);
            }
        }
    }

    //Control methods
    function startPreSale() public onlyOwner {
        _isPresale = true;
        saleOpen = true;
    }

    function isTransferable(bool _choice) public onlyOwner{
        transferable = _choice;
    }

    function startPublicSale() public onlyOwner {
        _isPresale = false;
        saleOpen = true;
        _maxQuads = MAX_QUADS;
        _maxMint = MAX_MINT;
    }

    function flipSaleState() public onlyOwner {
        saleOpen = !saleOpen;
    }

    function addToWhitelist(address whiltelisted) public onlyOwner {
        _whitelist[whiltelisted] = true;
    }

    function removeFromWhitelist(address whiltelisted) public onlyOwner {
        _whitelist[whiltelisted] = false;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setPrice(uint256  _newPrice) public onlyOwner {
            _price = _newPrice;
    }

    function setRoyaltyBPS(uint96  _newBPS) public onlyOwner {
            _royaltyBPS = _newBPS;
    }

    function setCanMintCenter(bool newCanMintCenter) external onlyOwner {
        canMintCenter = newCanMintCenter;
    }

     function setCanMintSpecial(bool newCanMintSpecial) external onlyOwner {
        canMintSpecial = newCanMintSpecial;
    }


       function lockFreeStyleToggle() public  onlyOwner {
        lockFreestyle = !lockFreestyle;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }


    //configure initial royalties for Rariable on minting
    function setInitialRoyalties(uint _tokenId, address payable recipient) private {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _royaltyBPS;
        _royalties[0].account = recipient;
        _saveRoyalties(_tokenId, _royalties);
    }
    
    //modify royalties for Rariable on individual tokens
    function setRoyalties(uint _tokenId, address payable _royaltiesRecipientAddress, uint96 _percentageBasisPoints) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesRecipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function setDefaultContentBaseURI(string memory newDefaultContentBaseURI) external onlyOwner {
        _defaultContentBaseURI = newDefaultContentBaseURI;
    }

    //read methods
    function price(uint256 _count) public view returns (uint256) {
        return _price.mul(_count);
    }

    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }

    function occupiedList() public view returns (uint256[] memory) {
        return _occupiedList;
    }

    function maxMint() public view returns (uint256) {
        return _maxMint;
    }

    function maxSales() public view returns (uint256) {
        return _maxQuads;
    }

    function maxSupply() public pure returns (uint256) {
        return MAX_QUADS;
    }

    function raised() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenIdsOfWallet(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

      function getParcelsCount() public view returns (uint256) {
        return parcelCount;
      }

    function getParcels() public view returns (Parcel[] memory){
         Parcel[] memory lParcels = new Parcel[](parcelCount);
        for (uint i = 0; i < parcelCount; i++) {
            Parcel storage lParcel = parcels[i + 1];
            lParcels[i] = lParcel;
        }

        return lParcels;
    }

    function getParcelData(uint256 parcelId) public view returns (Parcel memory) {
        return parcels[parcelId];
    }

    
    function getParcelTokens(uint256 _parcelId) 
        public 
        view
        returns (uint256[] memory r) 
    {
        uint256 x = parcels[_parcelId].coord % QUAD_COLUMNS;
        uint256 y = parcels[_parcelId].coord / QUAD_ROWS;
        uint256 height = parcels[_parcelId].height;
        uint256 width = parcels[_parcelId].width;
        uint256 total = width * height;

        uint i = 0;
        r = new uint256[](total);
        for (uint256 ix=x; ix<=x + width; ix++) {
            for (uint256 iy=y; iy<=y + height; iy++) {
                r[i] = _parcelId + (QUAD_ROWS * iy) + ix;
                i++;
            }
        }

        return r;
    }

    function metadataBaseURI() internal view returns (string memory) {
        return baseTokenURI;
    }

     function defaultContentBaseURI() internal view returns (string memory) {
        return _defaultContentBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenContentURIs[tokenId];
        
        if (bytes(_tokenURI).length == 0) {
             return string(abi.encodePacked(_defaultContentBaseURI, tokenId));
        }
        
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;       
        }
        
        return super.tokenURI(tokenId);
    }

    // royalties for Mintable using the ERC2981 standard
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
      //use the same royalties that were saved for Rariable
      LibPart.Part[] memory _royalties = royalties[_tokenId];
      if(_royalties.length > 0) {
        return (_royalties[0].account, (_salePrice * _royalties[0].value) / 10000);
      }
      return (address(0), 0);
    }

    //overides

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721,ERC721Enumerable) returns (bool) {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }

        if(interfaceId == _INTERFACE_ID_ERC2981) {
          return true;
        }

        return super.supportsInterface(interfaceId);
    }

}
