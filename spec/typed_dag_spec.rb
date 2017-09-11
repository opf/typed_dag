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
  end

  shared_examples_for 'single typed dag' do |configuration|
    down = configuration[:down]
    up = configuration[:up].is_a?(Hash) ? configuration[:up][:name] : configuration[:up]
    up_limit = configuration[:up].is_a?(Hash) ? configuration[:up][:limit] : nil
    # defining up and up_limit again here to capture the closure and by that avoid
    # having to pass them around as params
    let(:up) { configuration[:up].is_a?(Hash) ? configuration[:up][:name] : configuration[:up] }
    let(:up_limit) { configuration[:up].is_a?(Hash) ? configuration[:up][:limit] : nil }
    all_down = configuration[:all_down]
    all_down_depth = (configuration[:all_down].to_s + '_of_depth').to_sym
    all_up = configuration[:all_up]
    all_up_depth = (configuration[:all_up].to_s + '_of_depth').to_sym

    def up_one_or_array(message)
      if up_limit == 1
        message
      else
        Array(message)
      end
    end

    def message_with_up(text, parent)
      if up_limit == 1
        Message.create text: text, up => up_one_or_array(parent)
      else
        m = Message.create text: text
        m.send("#{up}=", up_one_or_array(parent))
        m
      end
    end

    describe "##{down} (directly down)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.new }

        it 'is empty' do
          expect(a.send(down))
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
        let!(:b) { message_with_up('B', a) }

        it 'includes B' do
          expect(a.send(down))
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }

        it 'includes B' do
          expect(a.send(down))
            .to match_array([b])
        end
      end
    end

    describe "##{all_down} (transitive down)" do
      description = <<-WITH

        DAG:
          A
      WITH

      context description do
        it 'is empty' do
          expect(message.send(all_down))
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
        let!(:b) { message_with_up 'B', a }

        it 'includes B' do
          expect(a.send(all_down))
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }

        it 'includes B and C' do
          expect(a.send(all_down))
            .to match_array([b, c])
        end
      end

      if !up_limit || up_limit > 1
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
          let!(:b) { message_with_up 'B', a }
          let!(:c) { message_with_up 'C', a }
          let!(:d) { message_with_up 'D', [b, c] }

          it 'is B, C and D for A' do
            expect(d.send(all_up))
              .to match_array([b, c, a])
          end
        end
      end
    end

    describe "##{up} (direct up)" do
      description = <<-WITH

        DAG:
          A
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }

        if up_limit == 1
          it 'is nil' do
            expect(a.send(up))
              .to be_nil
          end
        else
          it 'is empty' do
            expect(a.send(up))
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
        let!(:a) { message_with_up 'A', b }

        if up_limit && up_limit == 1
          it 'is B' do
            expect(a.send(up))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(up))
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
        let!(:b) { message_with_up 'B', c }
        let!(:a) { message_with_up 'A', b }

        if up_limit == 1
          it 'is B' do
            expect(a.send(up))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(up))
              .to match_array([b])
          end
        end
      end
    end

    describe "##{all_up} (transitive up)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is empty' do
          expect(a.send(all_up))
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
        let!(:b) { message_with_up 'B', c }
        let!(:a) { message_with_up 'A', b }

        it 'includes B and C' do
          expect(a.send(all_up))
            .to match_array([b, c])
        end
      end

      if !up_limit || up_limit > 1
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
          let!(:b) { message_with_up 'B', a }
          let!(:c) { message_with_up 'C', a }
          let!(:d) { message_with_up 'D', [b, c] }

          it 'is B, C and A for D' do
            expect(d.send(all_up))
              .to match_array([b, c, a])
          end
        end
      end
    end

    describe "#self_and_#{all_up} (self and transitive up)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is A' do
          expect(a.send(:"self_and_#{all_up}"))
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
        let!(:b) { message_with_up 'B', c }
        let!(:a) { message_with_up 'A', b }

        it 'for A is A, B and C' do
          expect(a.send(:"self_and_#{all_up}"))
            .to match_array([a, b, c])
        end
      end
    end

    describe "#self_and_#{all_down} (self and transitive down)" do
      description = <<-WITH

        DAG:
          A
      WITH
      context description do
        let!(:a) { Message.create text: 'A' }

        it 'is A' do
          expect(a.send(:"self_and_#{all_down}"))
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
        let!(:b) { message_with_up 'B', c }
        let!(:a) { message_with_up 'A', b }

        it 'for C is A, B and C' do
          expect(c.send(:"self_and_#{all_down}"))
            .to match_array([a, b, c])
        end
      end
    end

    describe "##{up}= (directly up)" do
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
          a.send("#{up}=", up_one_or_array(b))
        end

        if up_limit == 1
          it 'is B' do
            expect(a.send(up))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(up))
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
          a.attributes = { up => up_one_or_array(b) }
        end

        if up_limit == 1
          it 'is B' do
            expect(a.send(up))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(up))
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
          Message.create up => up_one_or_array(b)
        end

        before do
          a
        end

        if up_limit == 1
          it 'is B' do
            expect(a.send(up))
              .to eql b
          end
        else
          it 'includes B' do
            expect(a.send(up))
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
          b.send("#{up}=", up_one_or_array(c))
          a.send("#{up}=", up_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_up))
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
          b.send("#{up}=", up_one_or_array(a))
          c.send("#{up}=", up_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_down))
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
          b.send("#{up}=", up_one_or_array(a))
          c.send("#{up}=", up_one_or_array(b))
          d.send("#{up}=", up_one_or_array(b))
        end

        it 'builds the complete hierarchy' do
          expect(a.send(all_down))
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { Message.create text: 'C' }
        let!(:d) { message_with_up 'D', c }

        before do
          c.send("#{up}=", up_one_or_array(b))
        end

        it 'builds the complete transitive down for A' do
          expect(a.send(all_down))
            .to match_array([b, c, d])
        end

        it 'build the correct second generation down for A' do
          expect(a.send(all_down_depth, 2))
            .to match_array([c])
        end

        it 'build the correct third generation down for A' do
          expect(a.send(all_down_depth, 3))
            .to match_array([d])
        end

        it 'builds the complete transitive down for B' do
          expect(b.send(all_down))
            .to match_array([c, d])
        end

        it 'builds the complete transitive up for D' do
          expect(d.send(all_up))
            .to match_array([c, b, a])
        end

        it 'builds the complete transitive up for C' do
          expect(c.send(all_up))
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
          assigning nil/empty to C's up method
      WITH

      context description do
        let!(:a) { Message.create text: 'A' }
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }
        let!(:d) { message_with_up 'D', c }

        before do
          if up_limit == 1
            c.send("#{up}=", nil)
          else
            c.send("#{up}=", [])
          end
        end

        it 'empties transitive down for A except B' do
          expect(a.send(all_down))
            .to match_array [b]
        end

        it 'empties transitive down for B' do
          expect(b.send(all_down))
            .to be_empty
        end

        it 'empties down for B' do
          expect(b.send(down))
            .to be_empty
        end

        it 'empties transitive up for D except C' do
          expect(d.send(all_up))
            .to match_array([c])
        end

        it 'empties transitive up for C' do
          expect(c.send(all_up))
            .to be_empty
        end
      end
    end

    describe "#{all_down_depth} (all down of depth X)" do
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }
        let!(:d) { message_with_up 'D', b }

        it 'is B for A with depth 1' do
          expect(a.send(all_down_depth, 1))
            .to match_array [b]
        end

        it 'is C and D for A with depth 2' do
          expect(a.send(all_down_depth, 2))
            .to match_array [c, d]
        end
      end
    end

    describe "#{all_up_depth} (all up of depth X)" do
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }

        it 'is B for C with depth 1' do
          expect(c.send(all_up_depth, 1))
            .to match_array [b]
        end

        it 'is C and D for A with depth 2' do
          expect(c.send(all_up_depth, 2))
            .to match_array [a]
        end
      end

      if !up_limit || up_limit > 1
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
            message.send("#{up}=", [a, b])
            message
          end
          let!(:d) { message_with_up 'd', c }

          it 'is C for D with depth 1' do
            expect(d.send(all_up_depth, 1))
              .to match_array [c]
          end

          it 'is A and B for D with depth 2' do
            expect(d.send(all_up_depth, 2))
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
        let!(:b) { message_with_up 'B', a }
        let!(:c) { message_with_up 'C', b }
        let!(:d) { message_with_up 'D', c }

        before do
          c.destroy
        end

        it 'empties transitive down for A except B' do
          expect(a.send(all_down))
            .to match_array [b]
        end

        it 'empties transitive down for B' do
          expect(b.send(all_down))
            .to be_empty
        end

        it 'empties down for B' do
          expect(b.send(down))
            .to be_empty
        end

        it 'empties transitive up for D' do
          expect(d.send(all_up))
            .to be_empty
        end

        if up_limit == 1
          it "assigns nil to D's up" do
            d.reload
            expect(d.send(up))
              .to be_nil
          end
        else
          it 'empties up for D' do
            expect(d.send(all_up))
              .to be_empty
          end
        end
      end
    end

    describe '#destroy on a relation' do
      if !up_limit || up_limit > 1
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
          let!(:b) { message_with_up 'B', a }
          let!(:d) { message_with_up 'D', a }
          let!(:c) { message_with_up 'C', [a, b, d] }
          let!(:e) { message_with_up 'E', b }
          let!(:f) { message_with_up 'F', [e, c] }
          let!(:g) { message_with_up 'G', f }

          before do
            Relation.where(ancestor: c, descendant: f).destroy_all
          end

          it "#{all_down} (transitive down) of A is B, C, D, E, F, G" do
            expect(a.send(all_down))
              .to match_array([b, c, d, e, f, g])
          end

          it "#{all_down} (transitive down) of B is C, E, F, G" do
            expect(b.send(all_down))
              .to match_array([c, e, f, g])
          end

          it "#{all_down} (transitive down) of C is empty" do
            expect(c.send(all_down))
              .to be_empty
          end

          it "#{all_down} (transitive down) of D is C" do
            expect(d.send(all_down))
              .to match_array([c])
          end

          it "#{all_up} (transitive up) of F is E, B, A" do
            expect(f.send(all_up))
              .to match_array([e, b, a])
          end

          it "#{all_down_depth} (transitive down of depth) of A with depth 4 is G" do
            expect(a.send(all_down_depth, 4))
              .to match_array([g])
          end

          it "#{all_down_depth} (transitive down of depth) of A with depth 3 is F" do
            expect(a.send(all_down_depth, 3))
              .to match_array([f])
          end
        end
      end
    end
  end

  context 'hierarchy relations' do
    it_behaves_like 'single typed dag',
                    down: :children,
                    up: { name: :parent, limit: 1 },
                    all_down: :descendants,
                    all_up: :ancestors
  end

  context 'invalidate relations' do
    it_behaves_like 'single typed dag',
                    down: :invalidates,
                    up: :invalidated_by,
                    all_down: :all_invalidates,
                    all_up: :all_invalidated_by
  end

  context 'relations of various types' do
    def create_message_with_invalidated_by(text, invalidated_by)
      message = Message.create text: text
      message.invalidated_by = Array(invalidated_by)
      message
    end

    describe 'directly down' do
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

    describe 'transitive down' do
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

    describe 'transitive up' do
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
  end
end
