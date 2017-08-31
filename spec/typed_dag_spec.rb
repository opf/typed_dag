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

  describe '#children' do
    it 'is empty' do
      expect(message.children)
        .to be_empty
    end

    context 'with a child' do
      before do
        child_message
      end

      it 'includes the child' do
        expect(message.children)
          .to match_array([child_message])
      end
    end

    context 'with a grandchild' do
      before do
        child_message
        grandchild_message
      end

      it 'includes the child' do
        expect(message.children)
          .to match_array([child_message])
      end
    end
  end

  describe '#descendants' do
    it 'is empty' do
      expect(message.descendants)
        .to be_empty
    end

    context 'with a child' do
      before do
        child_message
      end

      it 'includes the child' do
        expect(message.descendants)
          .to match_array([child_message])
      end
    end

    context 'with a grandchild' do
      before do
        child_message
        grandchild_message
      end

      it 'includes the child and grandchild' do
        expect(message.descendants)
          .to match_array([child_message, grandchild_message])
      end
    end
  end

  describe '#parent' do
    it 'is nil' do
      expect(message.parent)
        .to be_nil
    end

    context 'with a parent' do
      before do
        parent_message
      end

      it 'returns the parent' do
        expect(message.parent)
          .to eql parent_message
      end
    end

    context 'with a grandparent' do
      before do
        parent_message
        grandparent_message
      end

      it 'returns the parent' do
        expect(message.parent)
          .to eql parent_message
      end
    end
  end

  describe '#ancestors' do
    it 'is empty' do
      expect(message.ancestors)
        .to be_empty
    end

    context 'with a parent' do
      before do
        parent_message
      end

      it 'includes the parent' do
        expect(message.ancestors)
          .to match_array([parent_message])
      end
    end

    context 'with a grandparent' do
      before do
        parent_message
        grandparent_message
      end

      it 'includes the parent and grandparent' do
        expect(message.ancestors)
          .to match_array([parent_message, grandparent_message])
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

  describe '#parent=' do
    context 'on assigning via method' do
      before do
        message.parent = other_message
      end

      it 'assigns the parent' do
        expect(message.parent)
          .to eql other_message
      end
    end

    context 'on assigning a hash to the attributes' do
      before do
        message.attributes = { parent: other_message }
      end

      it 'assigns the parent when using a hash' do
        expect(message.parent)
          .to eql other_message
      end
    end

    context 'on creation' do
      let(:message) do
        Message.create parent: other_message
      end

      before do
        message
      end

      it 'assigns the parent' do
        expect(message.parent)
          .to eql other_message
      end
    end

    context "on adding a work package as a parent's parent" do
      before do
        message.parent = other_message
        other_message.parent = another_message

        message.reload
      end

      it 'builds the complete hierarchy' do
        expect(message.ancestors)
          .to match_array([other_message, another_message])
      end
    end

    context "on adding a work package as a child's child" do
      before do
        other_message.parent = message
        another_message.parent = other_message

        message.reload
      end

      it 'builds the complete hierarchy' do
        expect(message.descendants)
          .to match_array([other_message, another_message])
      end
    end

    context 'on adding a child as a parent of a work package with a child' do
      before do
        other_message.parent = message
        yet_another_message.parent = another_message

        another_message.parent = other_message
      end

      it 'builds the complete hierarchy' do
        expect(message.descendants)
          .to match_array([other_message, another_message, yet_another_message])
      end
    end

    context 'on removing a parent (assign nil)' do
      before do
        message
        child_message

        child_message.parent = nil
      end

      it 'leads to the former parent no longer having children' do
        expect(message.children)
          .to be_empty
      end

      it 'leads to the former parent no longer having descendants' do
        expect(message.descendants)
          .to be_empty
      end
    end

    context 'on assigning nil to a parent' do
      before do
        message
        child_message
        grandchild_message

        child_message.parent = nil
      end

      it 'leads to the former parent no longer having children' do
        expect(message.children)
          .to be_empty
      end

      it 'leads to the former parent no longer having descendants' do
        expect(message.descendants)
          .to be_empty
      end
    end

    context "on assigning nil to a parent that had a child as it's parent" do
      before do
        message
        child_message
        grandchild_message
        grandgrandchild_message

        grandchild_message.parent = nil
      end

      it 'leads to the former parent no longer having children' do
        expect(child_message.children)
          .to be_empty
      end

      it 'leads to the former parent no longer having descendants' do
        expect(child_message.descendants)
          .to be_empty
      end

      it 'leads to the child no longer having ancestors apart from the parent' do
        expect(grandgrandchild_message.ancestors)
          .to match_array([grandchild_message])
      end

      it 'leads to the child no longer having ancestors apart from the parent' do
        expect(grandgrandchild_message.ancestors)
          .to match_array([grandchild_message])
      end

      it 'leads to the upperchild no longer having descendants' do
        expect(child_message.descendants)
          .to be_empty
      end
    end
  end
end
