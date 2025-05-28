// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Digital Goods Rental Smart Contract
 * @dev A decentralized platform for renting digital goods like software licenses, digital art, music, etc.
 * @author Digital Goods Rental Team
 */
contract DigitalGoodsRental {
    
    // Struct to represent a digital good
    struct DigitalGood {
        uint256 id;
        address owner;
        string name;
        string description;
        string accessUrl; // IPFS hash or encrypted access link
        uint256 pricePerDay;
        bool isAvailable;
        uint256 totalRentals;
    }
    
    // Struct to represent a rental agreement
    struct Rental {
        uint256 goodId;
        address renter;
        uint256 startTime;
        uint256 endTime;
        uint256 totalCost;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => DigitalGood) public digitalGoods;
    mapping(uint256 => Rental) public rentals;
    mapping(address => uint256[]) public ownerGoods;
    mapping(address => uint256[]) public renterHistory;
    
    uint256 public nextGoodId = 1;
    uint256 public nextRentalId = 1;
    uint256 public platformFeePercent = 5; // 5% platform fee
    address public platformOwner;
    
    // Events
    event DigitalGoodListed(uint256 indexed goodId, address indexed owner, string name, uint256 pricePerDay);
    event GoodRented(uint256 indexed rentalId, uint256 indexed goodId, address indexed renter, uint256 duration);
    event RentalEnded(uint256 indexed rentalId, uint256 indexed goodId);
    
    // Modifiers
    modifier onlyGoodOwner(uint256 _goodId) {
        require(digitalGoods[_goodId].owner == msg.sender, "Only good owner can perform this action");
        _;
    }
    
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can perform this action");
        _;
    }
    
    modifier goodExists(uint256 _goodId) {
        require(_goodId > 0 && _goodId < nextGoodId, "Digital good does not exist");
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: List a digital good for rental
     * @param _name Name of the digital good
     * @param _description Description of the digital good
     * @param _accessUrl IPFS hash or encrypted access URL
     * @param _pricePerDay Rental price per day in wei
     */
    function listDigitalGood(
        string memory _name,
        string memory _description,
        string memory _accessUrl,
        uint256 _pricePerDay
    ) external {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_pricePerDay > 0, "Price must be greater than 0");
        
        uint256 goodId = nextGoodId++;
        
        digitalGoods[goodId] = DigitalGood({
            id: goodId,
            owner: msg.sender,
            name: _name,
            description: _description,
            accessUrl: _accessUrl,
            pricePerDay: _pricePerDay,
            isAvailable: true,
            totalRentals: 0
        });
        
        ownerGoods[msg.sender].push(goodId);
        
        emit DigitalGoodListed(goodId, msg.sender, _name, _pricePerDay);
    }
    
    /**
     * @dev Core Function 2: Rent a digital good for specified duration
     * @param _goodId ID of the digital good to rent
     * @param _durationDays Number of days to rent
     */
    function rentDigitalGood(uint256 _goodId, uint256 _durationDays) 
        external 
        payable 
        goodExists(_goodId) 
    {
        DigitalGood storage good = digitalGoods[_goodId];
        
        require(good.isAvailable, "Digital good is not available for rent");
        require(good.owner != msg.sender, "Cannot rent your own digital good");
        require(_durationDays > 0, "Duration must be at least 1 day");
        
        uint256 totalCost = good.pricePerDay * _durationDays;
        require(msg.value >= totalCost, "Insufficient payment");
        
        // Calculate platform fee and owner payment
        uint256 platformFee = (totalCost * platformFeePercent) / 100;
        uint256 ownerPayment = totalCost - platformFee;
        
        // Create rental record
        uint256 rentalId = nextRentalId++;
        rentals[rentalId] = Rental({
            goodId: _goodId,
            renter: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + (_durationDays * 1 days),
            totalCost: totalCost,
            isActive: true
        });
        
        // Update digital good status
        good.isAvailable = false;
        good.totalRentals++;
        
        // Record rental for renter
        renterHistory[msg.sender].push(rentalId);
        
        // Transfer payments
        payable(good.owner).transfer(ownerPayment);
        payable(platformOwner).transfer(platformFee);
        
        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
        
        emit GoodRented(rentalId, _goodId, msg.sender, _durationDays);
    }
    
    /**
     * @dev Core Function 3: End rental (can be called by renter or automatically after expiry)
     * @param _rentalId ID of the rental to end
     */
    function endRental(uint256 _rentalId) external {
        require(_rentalId > 0 && _rentalId < nextRentalId, "Rental does not exist");
        
        Rental storage rental = rentals[_rentalId];
        require(rental.isActive, "Rental is already ended");
        require(
            msg.sender == rental.renter || 
            msg.sender == digitalGoods[rental.goodId].owner || 
            block.timestamp >= rental.endTime,
            "Not authorized to end rental or rental not expired"
        );
        
        // End the rental
        rental.isActive = false;
        digitalGoods[rental.goodId].isAvailable = true;
        
        emit RentalEnded(_rentalId, rental.goodId);
    }
    
    // View functions
    function getDigitalGood(uint256 _goodId) 
        external 
        view 
        goodExists(_goodId) 
        returns (DigitalGood memory) 
    {
        return digitalGoods[_goodId];
    }
    
    function getRental(uint256 _rentalId) 
        external 
        view 
        returns (Rental memory) 
    {
        require(_rentalId > 0 && _rentalId < nextRentalId, "Rental does not exist");
        return rentals[_rentalId];
    }
    
    function getOwnerGoods(address _owner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return ownerGoods[_owner];
    }
    
    function getRenterHistory(address _renter) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return renterHistory[_renter];
    }
    
    function isRentalActive(uint256 _rentalId) 
        external 
        view 
        returns (bool) 
    {
        if (_rentalId == 0 || _rentalId >= nextRentalId) return false;
        
        Rental memory rental = rentals[_rentalId];
        return rental.isActive && block.timestamp <= rental.endTime;
    }
    
    // Platform management functions
    function updatePlatformFee(uint256 _newFeePercent) 
        external 
        onlyPlatformOwner 
    {
        require(_newFeePercent <= 10, "Platform fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }
    
    function transferPlatformOwnership(address _newOwner) 
        external 
        onlyPlatformOwner 
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }
} 
