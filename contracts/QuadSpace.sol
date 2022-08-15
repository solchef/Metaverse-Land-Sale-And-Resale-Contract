(_to, tokenId, width, height, parcelUri);
        _widthdraw(owner(), address(this).balance);
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

    function isAnyInMiddle(uint256 tokenId, uint8 width, uint8 height) internal pure returns (bool) {
        for (uint8 y = 0; y < height; y++) {
            for (uint8 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                if (isInMiddle(innerTokenId)) {
                    return true;
                }
            }
        }

        return false;
    }

    function isAnyASpecialQuad(uint256 tokenId, uint8 width, uint8 height) internal pure returns (bool) {
        for (uint8 y = 0; y < height; y++) {
            for (uint8 x = 0; x < width; x++) {
                uint256 innerTokenId = tokenId + (QUAD_ROWS * y) + x;
                if (isInSpecial(innerTokenId)) {
                    return true;
                }
            }
        }
        return false;
    }

    //Control methods
    function startPreSale() public onlyOwner {
        _isPresale = true;
        SALE_OPEN = true;
    }

    function isTransferable(bool _choice) public onlyOwner{
        transferable = _choice;
    }

    function startPublicSale() public onlyOwner {
        _isPresale = false;
        SALE_OPEN = true;
        _maxQuads = MAX_QUADS;
        _maxMint = MAX_MINT;
    }

    function flipSaleState() public onlyOwner {
        SALE_OPEN = !SALE_OPEN;
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

    function price(uint256 _count) public view returns (uint256) {
        return _price.mul(_count);
    }

    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }

    func

tion occupiedList() public view returns (uint256[] memory) {
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

    function getParcels() public view returns (Parcel[] memory){
        Parcel[] memory lParcels = new Parcel[](parcelCount);
        for (uint i = 0; i < parcelCount; i++) {
            Parcel storage lParcel = parcels[i];
            lParcels[i] = lParcel;
        }
        return lParcels;
    }

    function getParcelsCount() public view returns (uint256) {
        return parcelCount;
    }

    function getParcelData(uint256 parcelId) public view returns (Parcel memory) {
        return parcels[parcelId];
    }

    function updateParcelData(uint256 parcelId , uint256 width, uint256 height, string memory parcelUri) public payable returns(uint256) {
        require(parcels[parcelId].owner == _msgSender(),"Only owner can update");
        
        address  parcelOwner =  _msgSender();
        uint256 prev_width = parcels[parcelId].width;
        uint256 prev_height = parcels[parcelId].height;
        uint256 x = parcelId % QUAD_COLUMNS;
        uint256 y = parcelId / QUAD_ROWS;
        uint256 prev_x = parcels[parcelId].coord % QUAD_COLUMNS;
        uint256 prev_y = parcels[parcelId].coord / QUAD_ROWS;

         uint256 newId = parcelCount + 1;
        
        if(lockFreestyle == true){
          if(prev_width == width && prev_height == height){
            parcels[parcelId] = (Parcel(parcelId, width, height, parcelOwner, parcelUri));
         }else{
             require(prev_width == width || prev_height == height,"Parcel splitting requires width or height to be the same");
            _createParcel(parcelOwner, parcelId, width, height, parcelUri);
            if(prev_width == width){
                if(prev_y > y){
                    parcels[parcelId] = (Parcel((QUAD_ROWS * (y - height)) + x, width, prev_height - height, parcelOwner, parcelUri));
                }else{
                    parcels[parcelId] = (Parcel((QUAD_ROWS * (y + height)) + x, width, height - prev_height, parcelOwner, parcelUri));
                }
            }else if(prev_height == height){
                if(prev_x > x){
                    parcels[parcelId] = (Parcel((QUAD_ROWS * y) + (x - width), prev_width - width, height, parcelOwner, parcelUri));
                }else{
                    parcels[parcelId] = (Parcel((QUAD_ROWS * y) + (x + width), width - prev_width, height, parcelOwner, parcelUri));
                }            
            }
            
         }
        }else{
            _createParcel(parcelOwner, parcelId, width, height, parcelUri);
        }
        return newId;
    }

    function lockFreeStyleToggle() public  onlyOwner {
        lockFreestyle = !lockFreestyle;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "WITHDRAW: No balance in contract");

        _widthdraw(owner(), address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "WITHDRAW: Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, toke

nId);
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

    //configure royalties for Mintable using the ERC2981 standard
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
      //use the same royalties that were saved for Rariable
      LibPart.Part[] memory _royalties = royalties[_tokenId];
      if(_royalties.length > 0) {
        return (_royalties[0].account, (_salePrice * _royalties[0].value) / 10000);
      }
      return (address(0), 0);
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
