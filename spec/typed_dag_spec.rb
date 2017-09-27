require 'spec_helper'

RSpec.describe TypedDag do
  it 'has a version number' do
    expect(TypedDag::VERSION).not_to be nil
  end

  let(:message) { Message.create }
  let(:other_message) { Message.create }
  let(:another_message) { Message.create }
  let(:yet_another_message) { Message.create }
  let(:child_message) { Message.create parent: message }
  let(:invalidated_message) { Message.create invalidated_by: message }
  let(:level2_invalidated_message) { Message.create invalidated_by: invalidated_message }
  let(:grandchild_message) { Message.create parent: child_message }
  let(:grandgrandchild_message) { Message.create parent: grandchild_message }
  let(:parent_message) do
    parent = Message.create
    message.parent = parent
    parent
  end
  let(:grandparent_message) do
    grandparent = Message.create
    parent_message.parent = grandparent
    grandparent
  end

  describe '#leaf?' do
    it 'is true' do
      expect(message)
        .to be_leaf
    end

    context 'unpersisted' do
      it 'is true' do
        msg = Message.new

        expect(msg)
          .to be_leaf
      end
    end

    context 'with a child' do
      before do
        child_message
      end

      it 'is false' do
        expect(message)
          .not_to be_leaf
      end
    end
  end

  describe '#in_closure?' do
    it 'is false' do
      expect(message.in_closure?(other_message))
        .to be_falsey
    end

    context 'with a grandparent' do
      before do
        parent_message
        grandparent_message
      end

      it 'is true' do
        expect(message.in_closure?(grandparent_message))
          .to be_truthy
      end
    end

    context 'with a grandchild' do
      before do
        child_message
        grandchild_message
      end

      it 'is true' do
        expect(message.in_closure?(grandchild_message))
          .to be_truthy
      end
    end
  end

  describe '#child?' do
    it 'is false' do
      expect(message)
        .not_to be_child
    end

    context 'with a parent' do
      before do
        parent_message
      end

      it 'is true' do
        expect(message)
          .to be_child
      end
    end
  end

  shared_examples_for 'single typed dag' do |configuration|
    type = configuration[:type]
    to = configuration[:to]
    from = configuration[:from].is_a?(Hash) ? configuration[:from][:name] : configuration[:from]
    from_limit = configuration[:from].is_a?(Hash) ? configuration[:from][:limit] : nil
    # defining from and from_limit again here to capture the closure and by that avoid
    # having to pass them around as params
    let(:from) do
      configuration[:from].is_a?(Hash) ? configuration[:from][:name] : configuration[:from]
    end
    let(:from_limit) { configuration[:from].is_a?(Hash) ? configuration[:from][:limit] : nil }
    all_to = configuration[:all_to]
    all_to_depth = (configuration[:all_to].to_s + '_of_depth').to_sym
    all_from = configuration[:all_from]
    all_from_depth = (configuration[:all_from].to_s + '_of_depth').to_sym

    def from_one_or_array(message)
      if from_limit == 1
        message
      else
        Array(message)
      end
    end

    def message_with_from(text, parent)
      if from_limit == 1
        Message.create text: text, from => from_one_or_array(parent)
      else
        m = Message.create text: text
        m.send("#{from}=", from_one_or_array(parent))
        m
      end
    end

    describe ".#{type}_root?" do
      let(:method_name) { "#{type}_root?" }

      description = <<-'WITH'

        DAG:
                A

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is true for A' do
          expect(a.send(method_name))
            .to be_truthy
        end
      end

      description = <<-'WITH'

        DAG:
                A
                |
                |
                +
                B

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }

        it 'is true for A' do
          expect(a.send(method_name))
            .to be_truthy
        end

        it 'is false for B' do
          expect(b.send(method_name))
            .to be_falsy
        end
      end
    end

    describe ".#{type}_leaves" do
      let(:method_name) { "#{type}_leaves" }

      description = <<-'WITH'

        DAG:
                A

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is A' do
          expect(Message.send(method_name))
            .to match_array [a]
        end
      end
      description = <<-'WITH'

        DAG:
                A
               / \
              /   \
             +     +
            B       F
           / \
          /   \
         +     +
        C       D
                |
                |
                +
                E

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }
        let!(:d) { message_with_from 'D', b }
        let!(:e) { message_with_from 'E', d }
        let!(:f) { message_with_from 'F', a }

        it 'is C, E, F' do
          expect(Message.send(method_name))
            .to match_array [c, e, f]
        end
      end
    end

    describe "##{type}_leaves" do
      let(:method_name) { "#{type}_leaves" }

      description = <<-'WITH'

        DAG:
                A
               / \
              /   \
             +     +
            B       F
           / \
          /   \
         +     +
        C       D
                |
                |
                +
                E

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }
        let!(:d) { message_with_from 'D', b }
        let!(:e) { message_with_from 'E', d }
        let!(:f) { message_with_from 'F', a }

        it 'for A is C, E, F' do
          expect(a.send(method_name))
            .to match_array [c, e, f]
        end
      end
    end

    describe "##{to} (directly to)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.new }

        it 'is empty' do
          expect(a.send(to))
            .to be_empty
        end
      end

      description = <<-WITH

        DAG:
          A
          |
          |
          |
          B
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from('B', a) }

        it 'includes B' do
          expect(a.send(to))
            .to match_array([b])
        end
      end

      description = <<-WITH

        DAG:
          A
          |
          |
          |
          B
          |
          |
          |
          C
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }

        it 'includes B' do
          expect(a.send(to))
            .to match_array([b])
        end
      end
    end

    describe "##{all_to} (transitive to)" do
      description = <<-WITH

        DAG:
          A
      WITH

      context description do
        it 'is empty' do
          expect(message.send(all_to))
            .to be_empty
        end
      end

      description = <<-WITH

        DAG:
          A
          |
          |
          |
          B
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }

        it 'includes B' do
          expect(a.send(all_to))
            .to match_array([b])
        end
      end

      description = <<-WITH

        DAG:
          A
          |
          |
          |
          B
          |
          |
          |
          C
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }

        it 'includes B and C' do
          expect(a.send(all_to))
            .to match_array([b, c])
        end
      end

      if !from_limit || from_limit > 1
        description = <<-'WITH'

          DAG:
                      A
                     / \
                    /   \
                   /     \
                  B       C
                   \     /
                    \   /
                     \ /
                      D
        WITH
        context description do
          let!(:a) { Message.create text: 'A' }
          let!(:b) { message_with_from 'B', a }
          let!(:c) { message_with_from 'C', a }
          let!(:d) { message_with_from 'D', [b, c] }

          it 'is B, C and D for A' do
            expect(d.send(all_from))
              .to match_array([b, c, a])
          end
        end
      end
    end

    describe "##{from} (direct from)" do
      description = <<-WITH

        DAG:
          A
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }

        if from_limit == 1
          it 'is nil' do
            expect(a.send(from))
              .to be_nil
          end
        else
          it 'is empty' do
            expect(a.send(from))
              .to be_empty
          end
        end
      end

      description = <<-WITH

        DAG:
          B
          |
          |
          |
          A
      WITH
      context description do
        let!(:b) { Message.create text: 'B' }
        let!(:a) { message_with_from 'A', b }

        if from_limit && from_limit == 1
          it 'is B' do
            expect(a.send(from))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(from))
              .to match_array([b])
          end
        end
      end

      description = <<-WITH

        DAG:
          C
          |
          |
          |
          B
          |
          |
          |
          A
      WITH
      context description do
        let!(:c) { Message.create text: 'C' }
        let!(:b) { message_with_from 'B', c }
        let!(:a) { message_with_from 'A', b }

        if from_limit == 1
          it 'is B' do
            expect(a.send(from))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(from))
              .to match_array([b])
          end
        end
      end
    end

    describe "##{all_from} (transitive from)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is empty' do
          expect(a.send(all_from))
            .to be_empty
        end
      end

      description = <<-WITH

        DAG:
          C
          |
          |
          |
          B
          |
          |
          |
          A
      WITH
      context description do
        let!(:c) { Message.create text: 'C' }
        let!(:b) { message_with_from 'B', c }
        let!(:a) { message_with_from 'A', b }

        it 'includes B and C' do
          expect(a.send(all_from))
            .to match_array([b, c])
        end
      end

      if !from_limit || from_limit > 1
        description = <<-'WITH'

          DAG:
                      A
                     / \
                    /   \
                   /     \
                  B       C
                   \     /
                    \   /
                     \ /
                      D
        WITH
        context description do
          let!(:a) { Message.create text: 'A' }
          let!(:b) { message_with_from 'B', a }
          let!(:c) { message_with_from 'C', a }
          let!(:d) { message_with_from 'D', [b, c] }

          it 'is B, C and A for D' do
            expect(d.send(all_from))
              .to match_array([b, c, a])
          end
        end
      end
    end

    describe "#self_and_#{all_from} (self and transitive from)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is A' do
          expect(a.send(:"self_and_#{all_from}"))
            .to match_array [a]
        end
      end

      description = <<-WITH

        DAG:
          C
          |
          |
          +
          B
          |
          |
          +
          A
      WITH
      context description do
        let!(:c) { Message.create text: 'C' }
        let!(:b) { message_with_from 'B', c }
        let!(:a) { message_with_from 'A', b }

        it 'for A is A, B and C' do
          expect(a.send(:"self_and_#{all_from}"))
            .to match_array([a, b, c])
        end
      end
    end

    describe "#self_and_#{all_to} (self and transitive to)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is A' do
          expect(a.send(:"self_and_#{all_to}"))
            .to match_array [a]
        end
      end

      description = <<-WITH

        DAG:
          C
          |
          |
          +
          B
          |
          |
          +
          A
      WITH
      context description do
        let!(:c) { Message.create text: 'C' }
        let!(:b) { message_with_from 'B', c }
        let!(:a) { message_with_from 'A', b }

        it 'for C is A, B and C' do
          expect(c.send(:"self_and_#{all_to}"))
            .to match_array([a, b, c])
        end
      end
    end

    describe "##{from}= (directly from)" do
      description = <<-WITH

        DAG before:
          A     B

        DAG after:
          B
          |
          |
          |
          A

        via:
          assigning via method
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B' }

        before do
          a.send("#{from}=", from_one_or_array(b))
        end

        if from_limit == 1
          it 'is B' do
            expect(a.send(from))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(from))
              .to match_array([b])
          end
        end
      end

      description = <<-WITH

        DAG before:
          A     B

        DAG after:
          B
          |
          |
          |
          A

        via:
          assigning to attributes as part of a hash
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B' }

        before do
          a.attributes = { from => from_one_or_array(b) }
        end

        if from_limit == 1
          it 'is B' do
            expect(a.send(from))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(from))
              .to match_array([b])
          end
        end
      end

      description = <<-WITH

        DAG before:
          B

        DAG after:
          B
          |
          |
          |
          A

        via:
          on creation
      WITH
      context description do
        let!(:b) { Message.create text: 'B' }
        let(:a) do
          Message.create from => from_one_or_array(b)
        end

        before do
          a
        end

        if from_limit == 1
          it 'is B' do
            expect(a.send(from))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(from))
              .to match_array([b])
          end
        end
      end

      description = <<-WITH

        DAG before:
          A       B       C

        DAG after:
          C
          |
          |
          |
          B
          |
          |
          |
          A

        Assigning top down
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B' }
        let!(:c) { Message.create text: 'C' }

        before do
          b.send("#{from}=", from_one_or_array(c))
          a.send("#{from}=", from_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_from))
            .to match_array([b, c])
        end
      end

      description = <<-WITH

        DAG before:
          A      B      C

        DAG after:
          A
          |
          |
          |
          B
          |
          |
          |
          C

        Assigning top down
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B' }
        let!(:c) { Message.create text: 'C' }

        before do
          b.send("#{from}=", from_one_or_array(a))
          c.send("#{from}=", from_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_to))
            .to match_array([b, c])
        end
      end

      description = <<-'WITH'

        DAG before:
          A      B      C      D

        DAG after:
          A
          |
          |
          |
          B
         / \
        /   \
       /     \
      C       D

        Assigning depth first
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B' }
        let!(:c) { Message.create text: 'C' }
        let!(:d) { Message.create text: 'D' }

        before do
          b.send("#{from}=", from_one_or_array(a))
          c.send("#{from}=", from_one_or_array(b))
          d.send("#{from}=", from_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_to))
            .to match_array([b, c, d])
        end
      end

      description = <<-WITH

        DAG before:
          A      C
          |      |
          |      |
          |      |
          B      D

        DAG after:
          A
          |
          |
          |
          B
          |
          |
          |
          C
          |
          |
          |
          D
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { Message.create text: 'C' }
        let!(:d) { message_with_from 'D', c }

        before do
          c.send("#{from}=", from_one_or_array(b))
        end

        it 'builds the complete transitive to for A' do
          expect(a.send(all_to))
            .to match_array([b, c, d])
        end

        it 'build the correct second generation to for A' do
          expect(a.send(all_to_depth, 2))
            .to match_array([c])
        end

        it 'build the correct third generation to for A' do
          expect(a.send(all_to_depth, 3))
            .to match_array([d])
        end

        it 'builds the complete transitive to for B' do
          expect(b.send(all_to))
            .to match_array([c, d])
        end

        it 'builds the complete transitive from for D' do
          expect(d.send(all_from))
            .to match_array([c, b, a])
        end

        it 'builds the complete transitive from for C' do
          expect(c.send(all_from))
            .to match_array([b, a])
        end
      end

      description = <<-WITH

        DAG before:
          A
          |
          |
          |
          B
          |
          |
          |
          C
          |
          |
          |
          D


        DAG after:
          A      C
          |      |
          |      |
          |      |
          B      D

        via:
          assigning nil/empty to C's from method
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }
        let!(:d) { message_with_from 'D', c }

        before do
          if from_limit == 1
            c.send("#{from}=", nil)
          else
            c.send("#{from}=", [])
          end
        end

        it 'empties transitive to for A except B' do
          expect(a.send(all_to))
            .to match_array [b]
        end

        it 'empties transitive to for B' do
          expect(b.send(all_to))
            .to be_empty
        end

        it 'empties to for B' do
          expect(b.send(to))
            .to be_empty
        end

        it 'empties transitive from for D except C' do
          expect(d.send(all_from))
            .to match_array([c])
        end

        it 'empties transitive from for C' do
          expect(c.send(all_from))
            .to be_empty
        end
      end

      description = <<-WITH

        DAG before:
          A
          |
          |
          |
          B
          |
          |
          |
          C


        DAG after:
          A      B
                 |
                 |
                 |
                 C

        via:
          assigning nil/empty to B's from method
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }

        before do
          if from_limit == 1
            b.send("#{from}=", nil)
          else
            b.send("#{from}=", [])
          end
        end

        it 'empties transitive to for A' do
          expect(a.send(all_to))
            .to be_empty
        end

        it 'transitive to for B is C' do
          expect(b.send(all_to))
            .to match_array [c]
        end

        it 'empties to for A' do
          expect(a.send(to))
            .to be_empty
        end

        it 'empties transitive from for B' do
          expect(b.send(all_from))
            .to be_empty
        end
      end

      description = <<-WITH

        DAG before (unpersisted):
          B
          |
          |
          |
          A

        assigning nil afterwards
      WITH
      context description do
        let!(:a) { Message.new text: 'A' }
        let!(:b) { Message.create text: 'B' }

        before do
          a.send("#{from}=", from_one_or_array(b))

          a.send("#{from}=", from_one_or_array(nil))
        end

        if from_limit == 1
          it 'is nil' do
            expect(a.send(from))
              .to be_nil
          end
        else
          it 'is empty' do
            expect(a.send(from))
              .to be_empty
          end
        end
      end
    end

    describe "#{all_to_depth} (all to of depth X)" do
      description = <<-'WITH'

        DAG before:
          A
          |
          |
          |
          B
         / \
        /   \
       /     \
      C       D
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }
        let!(:d) { message_with_from 'D', b }

        it 'is B for A with depth 1' do
          expect(a.send(all_to_depth, 1))
            .to match_array [b]
        end

        it 'is C and D for A with depth 2' do
          expect(a.send(all_to_depth, 2))
            .to match_array [c, d]
        end
      end
    end

    describe "#{all_from_depth} (all from of depth X)" do
      description = <<-'WITH'

        DAG before:
          A
          |
          |
          |
          B
          |
          |
          |
          C
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }

        it 'is B for C with depth 1' do
          expect(c.send(all_from_depth, 1))
            .to match_array [b]
        end

        it 'is C and D for A with depth 2' do
          expect(c.send(all_from_depth, 2))
            .to match_array [a]
        end
      end

      if !from_limit || from_limit > 1
        description = <<-'WITH'

          DAG before:
            A       B
             \     /
              \   /
               \ /
                C
                |
                |
                |
                D
        WITH
        context description do
          let!(:a) { Message.create text: 'A' }
          let!(:b) { Message.create text: 'B' }
          let!(:c) do
            message = Message.create text: 'C'
            message.send("#{from}=", [a, b])
            message
          end
          let!(:d) { message_with_from 'd', c }

          it 'is C for D with depth 1' do
            expect(d.send(all_from_depth, 1))
              .to match_array [c]
          end

          it 'is A and B for D with depth 2' do
            expect(d.send(all_from_depth, 2))
              .to match_array [a, b]
          end
        end
      end
    end

    describe '#destroy' do
      description = <<-WITH

        DAG before:
          A
          |
          |
          |
          B
          |
          |
          |
          C
          |
          |
          |
          D


        DAG after:
          A      D
          |
          |
          |
          B

        via:
          remove C
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_from 'B', a }
        let!(:c) { message_with_from 'C', b }
        let!(:d) { message_with_from 'D', c }

        before do
          c.destroy
        end

        it 'empties transitive to for A except B' do
          expect(a.send(all_to))
            .to match_array [b]
        end

        it 'empties transitive to for B' do
          expect(b.send(all_to))
            .to be_empty
        end

        it 'empties to for B' do
          expect(b.send(to))
            .to be_empty
        end

        it 'empties transitive from for D' do
          expect(d.send(all_from))
            .to be_empty
        end

        if from_limit == 1
          it "assigns nil to D's from" do
            d.reload
            expect(d.send(from))
              .to be_nil
          end
        else
          it 'empties from for D' do
            expect(d.send(all_from))
              .to be_empty
          end
        end
      end
    end

    describe '#destroy on a relation' do
      if !from_limit || from_limit > 1
        description = <<-'WITH'

          DAG before:
            A
           /|\
          / | \
         +  +  +
        B--+C+--D
        |   |
        |   |
        +   |
        E   |
         \  |
          \ |
           ++
            F
            |
            |
            |
            G


          DAG after:
            A
           /|\
          / | \
         +  +  +
        B--+C+--D
        |
        |
        +
        E
         \
          \
           +
            F
            |
            |
            +
            G

          via:
            remove edge between C and F
        WITH
        context description do
          let!(:a) { Message.create text: 'A' }
          let!(:b) { message_with_from 'B', a }
          let!(:d) { message_with_from 'D', a }
          let!(:c) { message_with_from 'C', [a, b, d] }
          let!(:e) { message_with_from 'E', b }
          let!(:f) { message_with_from 'F', [e, c] }
          let!(:g) { message_with_from 'G', f }

          before do
            Relation.where(from: c, to: f).destroy_all
          end

          it "#{all_to} (transitive to) of A is B, C, D, E, F, G" do
            expect(a.send(all_to))
              .to match_array([b, c, d, e, f, g])
          end

          it "#{all_to} (transitive to) of B is C, E, F, G" do
            expect(b.send(all_to))
              .to match_array([c, e, f, g])
          end

          it "#{all_to} (transitive to) of C is empty" do
            expect(c.send(all_to))
              .to be_empty
          end

          it "#{all_to} (transitive to) of D is C" do
            expect(d.send(all_to))
              .to match_array([c])
          end

          it "#{all_from} (transitive from) of F is E, B, A" do
            expect(f.send(all_from))
              .to match_array([e, b, a])
          end

          it "#{all_to_depth} (transitive to of depth) of A with depth 4 is G" do
            expect(a.send(all_to_depth, 4))
              .to match_array([g])
          end

          it "#{all_to_depth} (transitive to of depth) of A with depth 3 is F" do
            expect(a.send(all_to_depth, 3))
              .to match_array([f])
          end
        end
      end
    end
  end

  context 'hierarchy relations' do
    it_behaves_like 'single typed dag',
                    type: :hierarchy,
                    to: :children,
                    from: { name: :parent, limit: 1 },
                    all_to: :descendants,
                    all_from: :ancestors
  end

  context 'invalidate relations' do
    it_behaves_like 'single typed dag',
                    type: :invalidate,
                    to: :invalidates,
                    from: :invalidated_by,
                    all_to: :all_invalidates,
                    all_from: :all_invalidated_by
  end

  context 'relations of various types' do
    def create_message_with_invalidated_by(text, invalidated_by)
      message = Message.create text: text
      message.invalidated_by = Array(invalidated_by)
      message
    end

    describe 'directly to' do
      description = <<-'WITH'

        DAG:
                   ------- A -------
                  /                 \
        invalidate                   hierarchy
                /                     \
               B                       C
              / \                     / \
    invalidate   hierarchy  invalidate   hierarchy
            /     \                 /     \
           D       E               F       G
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:d) { create_message_with_invalidated_by('D', b) }
        let!(:e) { Message.create text: 'E', parent: b }
        let!(:c) { Message.create text: 'C', parent: a }
        let!(:f) { create_message_with_invalidated_by('F', c) }
        let!(:g) { Message.create text: 'G', parent: c }

        it '#invalidates for A includes B' do
          expect(a.invalidates)
            .to match_array([b])
        end

        it '#invalidates for B includes D' do
          expect(b.invalidates)
            .to match_array([d])
        end

        it '#children for A includes C' do
          expect(a.children)
            .to match_array([c])
        end

        it '#children for C includes G' do
          expect(c.children)
            .to match_array([g])
        end
      end
    end

    describe 'transitive to' do
      description = <<-'WITH'

        DAG:
                   ------- A -------
                  /                 \
        invalidate                   hierarchy
                /                     \
               B                       C
              / \                     / \
    invalidate   hierarchy  invalidate   hierarchy
            /     \                 /     \
           D       E               F       G
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:d) { create_message_with_invalidated_by('D', b) }
        let!(:e) { Message.create text: 'E', parent: b }
        let!(:c) { Message.create text: 'C', parent: a }
        let!(:f) { create_message_with_invalidated_by('F', c) }
        let!(:g) { Message.create text: 'G', parent: c }

        it '#all_invalidates for A are B and D' do
          expect(a.all_invalidates)
            .to match_array([b, d])
        end

        it '#descendants for A are C and G' do
          expect(a.descendants)
            .to match_array([c, g])
        end
      end
    end

    describe 'transitive from' do
      description = <<-'WITH'

        DAG:
                   ------- A -------
                  /                 \
        invalidate                   hierarchy
                /                     \
               B                       C
              / \                     / \
    invalidate   hierarchy  invalidate   hierarchy
            /     \                 /     \
           D       E               F       G
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:d) { create_message_with_invalidated_by('D', b) }
        let!(:e) { Message.create text: 'E', parent: b }
        let!(:c) { Message.create text: 'C', parent: a }
        let!(:f) { create_message_with_invalidated_by('F', c) }
        let!(:g) { Message.create text: 'G', parent: c }

        it '#all_invalidated_by for D are B and A' do
          expect(d.all_invalidated_by)
            .to match_array([b, a])
        end

        it '#all_invalidated_by for F is C' do
          expect(f.all_invalidated_by)
            .to match_array([c])
        end

        it '#all_invalidated_by for G is empty' do
          expect(g.all_invalidated_by)
            .to be_empty
        end

        it '#ancestors for G are C and A' do
          expect(g.ancestors)
            .to match_array([c, a])
        end

        it '#ancestors for C is A' do
          expect(c.ancestors)
            .to match_array([a])
        end

        it '#ancestors for D is empty' do
          expect(d.ancestors)
            .to be_empty
        end
      end

      description = <<-'WITH'

        DAG:
                    A
                   / \
         invalidate   hierarchy
                 /     \
                B       C
                 \     /
         invalidate   hierarchy
                   \ /
                    D
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:c) { Message.create text: 'C', parent: a }
        let!(:d) do
          message = Message.create text: 'D', parent: c
          message.invalidated_by = [b]
          message
        end

        it '#all_invalidates for A are B and D' do
          expect(a.all_invalidates)
            .to match_array([b, d])
        end

        it '#descendants for A are C and D' do
          expect(a.descendants)
            .to match_array([c, d])
        end

        it '#all_invalidated_by for D are B and A' do
          expect(d.all_invalidated_by)
            .to match_array([b, a])
        end

        it '#ancestors for D are C and A' do
          expect(d.ancestors)
            .to match_array([c, a])
        end
      end
    end

    describe '#destroy' do
      description = <<-'WITH'

        DAG before:
                   ------- A -------
                  /                 \
        invalidate                   hierarchy
                /                     \
               B                       C
              / \                     / \
    invalidate   hierarchy  invalidate   hierarchy
            /     \                 /     \
           D       E               F       G
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:d) { create_message_with_invalidated_by('D', b) }
        let!(:e) { Message.create text: 'E', parent: b }
        let!(:c) { Message.create text: 'C', parent: a }
        let!(:f) { create_message_with_invalidated_by('F', c) }
        let!(:g) { Message.create text: 'G', parent: c }

        description = <<-'WITH'

          DAG after (A deleted):
                 B                       C
                / \                     / \
      invalidate   hierarchy  invalidate   hierarchy
              /     \                 /     \
             D       E               F       G
        WITH

        context description do
          before do
            a.destroy
          end

          it '#all_invalidated_by for D is B' do
            expect(d.all_invalidated_by)
              .to match_array([b])
          end

          it '#all_invalidated_by for F is C' do
            expect(f.all_invalidated_by)
              .to match_array([c])
          end

          it '#all_invalidated_by for G is empty' do
            expect(g.all_invalidated_by)
              .to be_empty
          end

          it '#ancestors for G is C' do
            expect(g.ancestors)
              .to match_array([c])
          end

          it '#ancestors for C is empty' do
            expect(c.ancestors)
              .to be_empty
          end

          it '#ancestors for D is empty' do
            expect(d.ancestors)
              .to be_empty
          end
        end

        description = <<-'WITH'

          DAG after (C deleted):
               A        F        G
               |
           invalidate
               |
               B
              / \
    invalidate   hierarchy
            /     \
           D       E
        WITH

        context description do
          before do
            c.destroy
          end

          it '#descendants for A is empty' do
            expect(a.descendants)
              .to be_empty
          end

          it '#all_invalidates for A are B and D' do
            expect(a.all_invalidates)
              .to match_array([b, d])
          end

          it '#all_invalidated_by for D is B and A' do
            expect(d.all_invalidated_by)
              .to match_array([b, a])
          end

          it '#all_invalidated_by for F is empty' do
            expect(f.all_invalidated_by)
              .to be_empty
          end

          it '#all_invalidated_by for G is empty' do
            expect(g.all_invalidated_by)
              .to be_empty
          end

          it '#ancestors for G is empty' do
            expect(g.ancestors)
              .to be_empty
          end

          it '#ancestors for D is empty' do
            expect(d.ancestors)
              .to be_empty
          end
        end
      end
    end

    describe '#rebuild_dag!' do
      description = <<-'WITH'

        DAG (messed up transitive closures):
          A ------
         /|\      |
        i i i     h
       +  +  +    +
      B-i+C+i-D   H
      |   |       |
      i   |       h
      +   i       +
      E   |       I
       \  |      /
        i |     /
         ++    /
          F   /
          |  /
          i h
          ++
          G

      WITH
      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { create_message_with_invalidated_by('B', a) }
        let!(:d) { create_message_with_invalidated_by('D', a) }
        let!(:c) { create_message_with_invalidated_by('C', [a, b, d]) }
        let!(:e) { create_message_with_invalidated_by('E', b) }
        let!(:f) { create_message_with_invalidated_by('F', [e, c]) }
        let!(:h) { Message.create text: 'H', parent: a }
        let!(:i) { Message.create text: 'I', parent: h }
        let!(:g) do
          msg = Message.create text: 'G', parent: i
          msg.invalidated_by = [f]
          msg
        end

        before do
          Relation
            .where('hierarchy + invalidate > 1')
            .update_all('hierarchy = hierarchy + 10, invalidate = invalidate + 10')

          Message.rebuild_dag!
        end

        it '#descendants_of_depth(1) for A is H' do
          expect(a.descendants_of_depth(1))
            .to match_array([h])
        end

        it '#all_invalidates_of_depth(1) for A is B, C, D' do
          expect(a.all_invalidates_of_depth(1))
            .to match_array([b, c, d])
        end

        it '#descendants_of_depth(2) for A is H' do
          expect(a.descendants_of_depth(2))
            .to match_array([i])
        end

        it '#all_invalidates_of_depth(2) for A is C, E, F' do
          expect(a.all_invalidates_of_depth(2))
            .to match_array([c, e, f])
        end

        it '#descendants_of_depth(3) for A is G' do
          expect(a.descendants_of_depth(3))
            .to match_array([g])
        end

        it '#all_invalidates_of_depth(3) for A is G and F' do
          expect(a.all_invalidates_of_depth(3))
            .to match_array([g, f])
        end

        it '#descendants_of_depth(4) for A is empty' do
          expect(a.descendants_of_depth(4))
            .to be_empty
        end

        it '#all_invalidates_of_depth(4) for A is G' do
          expect(a.all_invalidates_of_depth(4))
            .to match_array([g])
        end
      end

      description = <<-'WITH'

        DAG (invalid) before:
           A
          + \
         i   h
        /     +
       C+--h---B

        DAG after:
           A
            \
             h
              +
       C+--h---B
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B', parent: a }
        let!(:c) { Message.create text: 'C', parent: b }
        let!(:invalid_relation) do
          Relation
            .new(from: c,
                 to: a,
                 invalidate: 1)
            .save(validate: false)
        end

        before do
          Message.rebuild_dag!
        end

        it '#descendants_of_depth(1) for A is B' do
          expect(a.descendants_of_depth(1))
            .to match_array([b])
        end

        it '#descendants_of_depth(2) for A is C' do
          expect(a.descendants_of_depth(2))
            .to match_array([c])
        end

        it '#all_invalidates_of_depth(1) for C is empty' do
          expect(c.all_invalidates_of_depth(1))
            .to be_empty
        end
      end

      description = <<-'WITH'

        DAG (invalid) before:
        --+A
       |  + \
       i i   h
       |/     +
       C+--h---B
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { Message.create text: 'B', parent: a }
        let!(:c) { Message.create text: 'C', parent: b }
        let!(:invalid_relation) do
          Relation
            .new(from: c,
                 to: a,
                 invalidate: 1)
            .save(validate: false)

          Relation
            .new(from: c,
                 to: a,
                 invalidate: 1)
            .save(validate: false)
        end

        it 'throws an error if more attepts than specified are made' do
          expect { Message.rebuild_dag!(1) }
            .to raise_error(TypedDag::RebuildDag::AttemptsExceededError)
        end
      end
    end
  end
end
