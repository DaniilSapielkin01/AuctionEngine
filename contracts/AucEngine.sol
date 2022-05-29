// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AucEngine {
    address public owner;
    // immutable or constant
    uint constant DURATION = 2 days;
    uint constant FEE = 10; // 10%

    struct Auction {
        address payable seller;
        uint startingPrice;
        uint finalPrice;
        uint startAt;
        uint endsAt;
        uint discountRate;
        string item;
        bool stopped;
    }

    Auction[] public auctions;
    // событие мы можешь только записывать , но не читать из контракта
    event AuctionCreated(uint index, string itemName, uint startingPrice, uint duraction );
    event AuctionEnded(uint index, uint finalPrice, address winner);

    constructor() {
        owner = msg.sender;
    }

    // calldata - неизменяемая временное хранилище
    // memory - изменяемое временное хранилище
    function createAuction(
     uint _startingPrice,
     uint _discountRate,
     string calldata _item,
     uint _duration
     ) external {
         uint duration = _duration == 0 ? DURATION : _duration; 
         require(_startingPrice >= _discountRate * duration, "incorrect starting price");

         Auction memory newAuction = Auction({
           seller: payable(msg.sender),
           startingPrice: _startingPrice,
           finalPrice: _startingPrice,
           discountRate: _discountRate,
           startAt: block.timestamp,
           endsAt: block.timestamp + duration,
           item: _item,
           stopped: false
         });

         auctions.push(newAuction);

         emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    function getPriceFor(uint _index) public view returns(uint) {
      Auction memory cAuction = auctions[_index];
      require(!cAuction.stopped, "stopped!");
      uint elapsed = block.timestamp - cAuction.startAt;
      uint discount = cAuction.discountRate * elapsed;

      return cAuction.startingPrice - discount;
    }

    function stop(uint _index) public {
      Auction storage cAuction = auctions[_index];
      cAuction.stopped = true;
    }

    function buy(uint _index) external payable {
      Auction storage cAuction = auctions[_index];
      require(!cAuction.stopped, "stopped!");
      require(block.timestamp < cAuction.endsAt, "ended auction!");
      uint cPrice = getPriceFor(_index);

      require(msg.value >= cPrice, "not enough funds!");

      cAuction.stopped = true;
      cAuction.finalPrice = cPrice;
      // каждую секунду цена может менятся и возможно придется возращать сдачу
      uint refund = msg.value - cPrice;
      if(refund > 0) {
        payable(msg.sender).transfer(refund);
      }

      cAuction.seller.transfer(
        cPrice - ((cPrice * FEE ) / 100)
      ); // 500 => 500 - ((500 * FEE) / 100) = 450

      // msg.sender - тот кто победил в аукционне 
      emit AuctionEnded(_index, cPrice, msg.sender);
    }
}