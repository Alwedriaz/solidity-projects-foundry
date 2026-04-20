// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract Marketplace {
    uint256 public itemCount;

    struct Item {
        uint256 id;
        address payable seller;
        string name;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => Item) public items;

    event ItemListed(uint256 indexed itemId, address indexed seller, string name, uint256 price);
    event ItemPurchased(uint256 indexed itemId, address indexed buyer, uint256 price);

    function listItem(string memory name, uint256 price) public {
        require(bytes(name).length > 0, "Nama tidak boleh kosong");
        require(price > 0, "Harga harus lebih dari 0");

        itemCount++;

        items[itemCount] = Item({
            id: itemCount,
            seller: payable(msg.sender),
            name: name,
            price: price,
            sold: false
        });

        emit ItemListed(itemCount, msg.sender, name, price);
    }

    function buyItem(uint256 itemId) public payable {
        require(itemId > 0 && itemId <= itemCount, "Item tidak valid");

        Item storage item = items[itemId];

        require(!item.sold, "Item sudah terjual");
        require(msg.value == item.price, "Jumlah ETH salah");
        require(msg.sender != item.seller, "Seller tidak bisa membeli item sendiri");

        item.sold = true;

        (bool success, ) = item.seller.call{value: msg.value}("");
        require(success, "Transfer gagal");

        emit ItemPurchased(itemId, msg.sender, msg.value);
    }

    function getItem(uint256 itemId)
        public
        view
        returns (
            uint256 id,
            address seller,
            string memory name,
            uint256 price,
            bool sold
        )
    {
        Item memory item = items[itemId];
        return (item.id, item.seller, item.name, item.price, item.sold);
    }
}