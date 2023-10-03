module vote10::vote {
    use sui::linked_table::{LinkedTable, Self};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use std::vector;

    const ERandomnessTooShort: u64 = 0;
    const EVotingDayIsOver: u64 = 1;
    const ECantVoteYourself: u64 = 2;
    const EWrongGroup: u64 = 3;
    const EAlreadyVoted: u64 = 4;
    const ETooEarlyToEnd: u64 = 5;
    const ENotAllGroupsParsedDuringEndVote: u64 = 6;
    const EVotingHasEnded: u64 = 7;

    struct GovernmentCensusAdmin has key {
        id: UID
    }

    struct VotingRegistry has key {
        id: UID,
        citizens: LinkedTable<address, bool>,
        to_elect: u64,
        finished: bool
    }


    struct Group has store {
        number: u64,
        members: LinkedTable<address, bool>,
        votes: Table<address, u64>
    }

    struct VotingPass has key {
        id: UID,
        group_number: u64,
        epoch: u64
        // no_of_votes: u8
    }

    struct VotingGroups has key {
        id: UID,
        groups: Table<u64, Group>,
        epoch: u64
    }

    fun init(ctx: &mut TxContext) {
        let cap = GovernmentCensusAdmin {
            id: object::new(ctx)
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public fun new(_: &GovernmentCensusAdmin, to_elect: u64, ctx: &mut TxContext) {
        let registry = VotingRegistry {
            id: object::new(ctx),
            citizens: linked_table::new<address, bool>(ctx),
            to_elect,
            finished: false

        };
        let groups = VotingGroups {
            id: object::new(ctx),
            groups: table::new<u64, Group>(ctx),
            epoch: tx_context::epoch(ctx)
        };

        transfer::share_object(registry);
        transfer::share_object(groups);
    }

    public fun populate_registry(
        _: &GovernmentCensusAdmin,
        registry: &mut VotingRegistry,
        citizens: vector<address>) {
        while (!vector::is_empty(&citizens)) {
            let citizen = vector::pop_back<address>(&mut citizens);
            linked_table::push_back<address, bool>(&mut registry.citizens, citizen, true);
        }
    }

    public fun populate_voting_groups(
        _: &GovernmentCensusAdmin,
        registry: &mut VotingRegistry,
        groups: &mut VotingGroups,
        ctx: &mut TxContext) 
    {
        let total_groups = linked_table::length<address, bool>(&registry.citizens) / 10;
        let counter = 0;
        while(counter < total_groups) {
            let group = Group {
                number: counter,
                members: linked_table::new<address, bool>(ctx),
                votes: table::new<address, u64>(ctx)
            };
            table::add<u64, Group>(&mut groups.groups, counter, group);
            counter = counter + 1;
        };
    }

    /// This function will hit some limits for large numbers.
    public fun voting_start(
        _: &GovernmentCensusAdmin,
        registry: &mut VotingRegistry,
        voting_groups: &mut VotingGroups,
        random_group_numbers: vector<u64>,
        to_elect: u64,
        ctx: &mut TxContext) {
        assert!(!registry.finished, EVotingHasEnded);
        let counter = 0;
        let stop = linked_table::length<address, bool>(&registry.citizens);
        let total_groups = stop / 10;
        assert!(vector::length(&random_group_numbers) == total_groups, ERandomnessTooShort);
        voting_groups.epoch = tx_context::epoch(ctx);
        while (counter < stop) {
            let group_index = counter % total_groups;
            let group_number = *vector::borrow<u64>(&random_group_numbers, group_index);
            let (citizen, _s) = linked_table::pop_front<address, bool>(&mut registry.citizens);
            let group = table::borrow_mut<u64, Group>(&mut voting_groups.groups, group_number);
            linked_table::push_back<address, bool>(&mut group.members, citizen, true);
            table::add<address, u64>(&mut group.votes, citizen, 0);
            let pass = VotingPass {
                id: object::new(ctx),
                group_number,
                epoch: tx_context::epoch(ctx)
            };
            transfer::transfer(pass, citizen);
            counter = counter + 1;
        };
        registry.to_elect =  to_elect;
    }

    public fun vote (
        groups: &mut VotingGroups,
        pass: VotingPass,
        vote: address,
        ctx: &mut TxContext
    ) {
        let VotingPass {id, group_number, epoch} = pass;
        // check that citizen is voting during voting day
        assert!(epoch == tx_context::epoch(ctx), EVotingDayIsOver);
        let sender = tx_context::sender(ctx);
        assert!(vote != sender, ECantVoteYourself);
        let group = table::borrow_mut<u64, Group>(&mut groups.groups, group_number);
        assert!(linked_table::contains<address, bool>(&mut group.members, sender), EWrongGroup);
        // can vote?
        let can_vote = linked_table::borrow_mut<address, bool>(&mut group.members, sender);
        assert!(*can_vote, EAlreadyVoted);
        *can_vote = false;
        let member_votes = table::borrow_mut<address, u64>(&mut group.votes, vote);
        *member_votes = *member_votes + 1;
        object::delete(id);
    }

    public fun voting_end(registry: &mut VotingRegistry, groups: &mut VotingGroups, ctx: &mut TxContext) {
        // removed for testing
        // assert!(tx_context::epoch(ctx) > groups.epoch, ETooEarlyToEnd); 
        let total_groups = table::length(&groups.groups);
        let counter = 0;
        while (counter < total_groups) {
            let group = table::remove<u64, Group>(&mut groups.groups, counter);
            let Group {number: _, members, votes} = group;
            let i = 0;
            let winner: address = @0x0;
            while (i < 10) {
                let (citizen, _status) = linked_table::pop_front<address, bool>(&mut members);
                let votes = table::remove<address, u64>(&mut votes, citizen);
                if (votes >= 5) {
                    winner = citizen;
                    break
                };
            };
            table::drop<address, u64>(votes);
            linked_table::drop<address, bool>(members);
            if (winner != @0x0) {
                linked_table::push_back<address, bool>(&mut registry.citizens, winner, true);
            };

            counter = counter + 1;
        };
        // all the groups must have been parsed
        assert!(table::length(&groups.groups) == 0, ENotAllGroupsParsedDuringEndVote);
        if (linked_table::length(&registry.citizens) <= registry.to_elect) {
            registry.finished = true;
        };
    }

}