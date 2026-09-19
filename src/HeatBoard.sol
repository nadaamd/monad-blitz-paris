// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title HeatBoard — a leaderboard where support cools down
/// @notice Classic on-chain voting is a ratchet: a vote cast once counts forever.
///         HeatBoard stores *heat* instead of votes. Every cheer adds heat, and heat
///         decays linearly back to zero over DECAY_WINDOW. A project only stays at the
///         top of the board as long as people keep cheering for it, right now.
///         The mechanic is only practical on a chain where a transaction is cheap and
///         confirms fast enough to be a real-time interaction — hence Monad.
contract HeatBoard {
    /// @dev Heat added by a single cheer (18 decimals, like an ERC-20 unit).
    uint256 public constant CHEER_HEAT = 1e18;
    /// @dev Time for a cheer to decay from CHEER_HEAT to zero.
    uint256 public constant DECAY_WINDOW = 1 hours;
    /// @dev Minimum delay between two cheers from the same address on the same entry.
    uint256 public constant COOLDOWN = 30 seconds;

    struct Entry {
        string name;
        address creator;
        uint256 heat; // heat snapshot at lastUpdate
        uint64 lastUpdate; // timestamp of the snapshot
        uint64 cheers; // lifetime cheer count, never decays
    }

    Entry[] private _entries;
    /// @notice entryId => cheerer => timestamp of their last cheer
    mapping(uint256 => mapping(address => uint64)) public lastCheerAt;

    event EntryCreated(uint256 indexed id, string name, address indexed creator);
    event Cheered(uint256 indexed id, address indexed fan, uint256 heatAfter);

    error EmptyName();
    error UnknownEntry();
    error StillCoolingDown(uint256 secondsLeft);

    /// @notice Register a new entry on the board.
    function createEntry(string calldata name) external returns (uint256 id) {
        if (bytes(name).length == 0) revert EmptyName();
        id = _entries.length;
        _entries.push(
            Entry({name: name, creator: msg.sender, heat: 0, lastUpdate: uint64(block.timestamp), cheers: 0})
        );
        emit EntryCreated(id, name, msg.sender);
    }

    /// @notice Add heat to an entry. Free, repeatable, and it fades.
    function cheer(uint256 id) external {
        if (id >= _entries.length) revert UnknownEntry();

        uint64 last = lastCheerAt[id][msg.sender];
        if (last != 0 && block.timestamp < last + COOLDOWN) {
            revert StillCoolingDown(last + COOLDOWN - block.timestamp);
        }
        lastCheerAt[id][msg.sender] = uint64(block.timestamp);

        Entry storage e = _entries[id];
        e.heat = _decayed(e.heat, e.lastUpdate) + CHEER_HEAT;
        e.lastUpdate = uint64(block.timestamp);
        e.cheers += 1;

        emit Cheered(id, msg.sender, e.heat);
    }

    /// @notice Current heat of an entry, decay applied as of now.
    function heatOf(uint256 id) public view returns (uint256) {
        if (id >= _entries.length) revert UnknownEntry();
        Entry storage e = _entries[id];
        return _decayed(e.heat, e.lastUpdate);
    }

    function entryCount() external view returns (uint256) {
        return _entries.length;
    }

    /// @notice Whole board in one call: names, live heat, lifetime cheers, creators.
    function board()
        external
        view
        returns (string[] memory names, uint256[] memory heat, uint64[] memory cheers, address[] memory creators)
    {
        uint256 n = _entries.length;
        names = new string[](n);
        heat = new uint256[](n);
        cheers = new uint64[](n);
        creators = new address[](n);
        for (uint256 i; i < n; ++i) {
            Entry storage e = _entries[i];
            names[i] = e.name;
            heat[i] = _decayed(e.heat, e.lastUpdate);
            cheers[i] = e.cheers;
            creators[i] = e.creator;
        }
    }

    /// @notice Seconds remaining before `fan` may cheer entry `id` again.
    function cooldownLeft(uint256 id, address fan) external view returns (uint256) {
        uint64 last = lastCheerAt[id][fan];
        if (last == 0 || block.timestamp >= last + COOLDOWN) return 0;
        return last + COOLDOWN - block.timestamp;
    }

    /// @dev Linear decay: heat reaches zero DECAY_WINDOW seconds after the snapshot.
    function _decayed(uint256 heat, uint64 since) private view returns (uint256) {
        uint256 elapsed = block.timestamp - since;
        if (elapsed >= DECAY_WINDOW) return 0;
        return heat - (heat * elapsed) / DECAY_WINDOW;
    }
}
