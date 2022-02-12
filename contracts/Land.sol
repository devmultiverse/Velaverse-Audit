// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IToken {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract Land is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControl
{
    using Counters for Counters.Counter;

    event bought(
        uint256[] zone,
        uint256[] x,
        uint256[] y,
        address wallet,
        uint256[] tokenId
    );

    event transferred(address from, address to, uint256 tokenId);

    struct sLand {
        uint256 zone;
        uint256 x;
        uint256 y;
        address wallet;
        uint256 tokenId;
    }

    struct Coord {
        uint256 xStart;
        uint256 xEnd;
        uint256 yStart;
        uint256 yEnd;
    }

    sLand[] allLands;

    uint256 public pricePerLand = 100;
    string public baseUrl =
        "https://gateway.pinata.cloud/ipfs/QmdiAbZkbBBm8fpzykbPmzPxjHEeViRdiyG3mGef2amcfy";
    address _globalWallet = 0x6B60BEfe688834AB5CA33b43FA5130B960117C43;
    IToken token;

    Coord[] restricted;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    constructor(address _token) ERC721("LAND", "LAND") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        token = IToken(_token);
    }

    function safeMint(address to, string memory uri) private returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function hasOwner(
        uint256 _zone,
        uint256 _x,
        uint256 _y
    ) private view returns (bool) {
        for (uint256 i = 0; i < allLands.length; i++)
            if (
                allLands[i].x == _x &&
                allLands[i].y == _y &&
                allLands[i].zone == _zone &&
                allLands[i].wallet != address(0)
            ) return true;
        return false;
    }

    function buyLands(
        uint256[] memory _zone,
        uint256[] memory _x,
        uint256[] memory _y
    ) public {
        require(
            _zone.length == _x.length && _zone.length == _y.length,
            "Invalid array length"
        );
        require(
            token.allowance(msg.sender, address(this)) >=
                pricePerLand * 1 ether * _zone.length,
            "Allowance balance is not enough"
        );
        require(
            token.balanceOf(msg.sender) >=
                pricePerLand * 1 ether * _zone.length,
            "Balance is not enough"
        );

        uint256[] memory tokenIdMint = new uint256[](uint256(_zone.length));
        for (uint256 i = 0; i < _zone.length; i++) {
            require(!hasOwner(_zone[i], _x[i], _y[i]), "Land is owned");
            require(!hasRestrictedArea(_x[i], _y[i]), "Land is not available");

            tokenIdMint[i] = safeMint(msg.sender, baseUrl);
            require(tokenIdMint[i] >= 0, "Token ID is invalid");

            allLands.push(
                sLand({
                    zone: _zone[i],
                    x: _x[i],
                    y: _y[i],
                    tokenId: tokenIdMint[i],
                    wallet: payable(msg.sender)
                })
            );
        }
        token.transferFrom(
            msg.sender,
            _globalWallet,
            pricePerLand * 1 ether * _zone.length
        );

        emit bought(_zone, _x, _y, msg.sender, tokenIdMint);
    }

    function getLands() public view returns (sLand[] memory) {
        return allLands;
    }

    function getLandWithOwner(address _address)
        public
        view
        returns (sLand[] memory)
    {
        sLand[] memory _owned = new sLand[](balanceOf(_address));

        uint256 index = 0;
        for (uint256 i = 0; i < allLands.length; i++) {
            if (allLands[i].wallet == _address) {
                _owned[index] = allLands[i];
                index++;
            }
        }
        return _owned;
    }

    function getLandWithTokenId(uint256 _tokenId)
        public
        view
        returns (sLand memory)
    {
        for (uint256 i = 0; i < allLands.length; i++)
            if (allLands[i].tokenId == _tokenId) return allLands[i];
        return sLand({zone: 0, x: 0, y: 0, tokenId: 0, wallet: address(0)});
    }

    function setPricePerLand(uint256 _price) public onlyRole(MINTER_ROLE) {
        require(_price > 0, "Price amount is not valid");
        pricePerLand = _price;
    }

    function setBaseUrl(string memory _url) public onlyRole(MINTER_ROLE) {
        require(bytes(_url).length > 0, "URL length must be greater than zero");

        baseUrl = _url;
    }

    function hasRestrictedArea(uint256 x, uint256 y)
        private
        view
        returns (bool)
    {
        for (uint256 i = 0; i < restricted.length; i++)
            if (
                (x >= restricted[i].xStart && x <= restricted[i].xEnd) &&
                (y >= restricted[i].yStart && y <= restricted[i].yEnd)
            ) return true;
        return false;
    }

    function addRestrictedArea(
        uint256[] memory xStart,
        uint256[] memory xEnd,
        uint256[] memory yStart,
        uint256[] memory yEnd
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            (xStart.length == xEnd.length) &&
                (yStart.length == yEnd.length) &&
                (xStart.length == yStart.length),
            "Invalid array length"
        );
        for (uint256 i = 0; i < xStart.length; i++) {
            restricted.push(
                Coord({
                    xStart: xStart[i],
                    xEnd: xEnd[i],
                    yStart: yStart[i],
                    yEnd: yEnd[i]
                })
            );
        }
    }

    function removeRestrictedArea(
        uint256 xStart,
        uint256 xEnd,
        uint256 yStart,
        uint256 yEnd
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < restricted.length; i++) {
            if (
                restricted[i].xStart == xStart &&
                restricted[i].xEnd == xEnd &&
                restricted[i].yStart == yStart &&
                restricted[i].yEnd == yEnd
            ) {
                delete restricted[i];
            }
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        super.transferFrom(from, to, tokenId);
        changeOwner(tokenId, to);
        emit transferred(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        super.safeTransferFrom(from, to, tokenId);
        changeOwner(tokenId, to);
        emit transferred(from, to, tokenId);
    }

    function changeOwner(uint256 _tokenId, address _to) private {
        for (uint256 i = 0; i < allLands.length; i++) {
            if (allLands[i].tokenId == _tokenId) {
                allLands[i].wallet = _to;
                break;
            }
        }
    }
}
