require 'config_hash'

RSpec.describe ConfigHash do
  let(:root) do
    {
      k: [
        {
          v: :bar,
          'x' => [
            'test',
            { true => 'z' }
          ],
        },
        3,
        [
          2,
          { 'test' => true }
        ]
      ],
      1 => {
        x: {
          z: 3
        }
      }
    }
  end
  let(:config_hash) { ConfigHash.new(root, options) }
  let(:options) { {} }

  describe 'initialization options' do
    subject { config_hash }

    describe ':freeze' do
      it 'defaults to true, and freezes values when true' do
        expect(subject.k).to be_frozen # root
        expect(subject[1].x).to be_frozen # intermediary
        expect(subject.k[0]['x'][1][true]).to be_frozen # leaf
      end

      context 'freeze: false' do
        let(:options) { {freeze: false} }

        it 'does not freeze values' do
          expect(subject.k).to_not be_frozen # root
          expect(subject[1].x).to_not be_frozen # intermediary
          expect(subject.k[0]['x'][1][true]).to_not be_frozen # leaf
        end
      end
    end

    describe ':processors' do
      context 'when defined as not an array' do
        let(:options) { {processors: 'foo'} }
        it 'raises an error' do
          expect{ subject }.to raise_error(ArgumentError)
        end
      end

      context 'when defined as an array with a non-callable' do
        let(:options) { {processors: ['foo']} }
        it 'raises an error' do
          expect{ subject }.to raise_error(ArgumentError)
        end
      end
    end

    describe 'ConfigHash::Processors special keys' do
      let(:options) { {constantize: true} }
      it 'adds it to the processors list' do
        expect(subject.instance_variable_get(:@processors)).to eq(
          [ConfigHash::Processors.method(:constantize)]
        )
      end
    end
  end

  describe '#[]' do
    it 'converts strings to symbols' do
      expect(config_hash['k']).to eq config_hash[:k]
    end

    context 'with a processor' do
      let(:options) { {processors: [->(v) { v.is_a?(Numeric) ? v+5 : v}] } }

      it 'returns the processed value' do
        expect(config_hash[1][:x][:z]).to eq 8 # from 3 + 5
      end
    end
  end

  describe '#method_missing' do
    context 'when freeze is true' do
      it 'raises an error on assignment' do
        expect{ config_hash.foo = :bar }.to raise_error(NoMethodError)
      end
    end

    context 'when freeze is false' do
      let(:options) { {freeze: false} }
      it 'returns nil for an accessor' do
        expect(config_hash.foo).to be_nil
      end

      it 'allows assignment, creating method accessor' do
        config_hash.foo = :bar
        expect(config_hash.foo).to eq :bar
      end
    end
  end

  describe '#delete' do
    context 'when freeze is true' do
      it 'raises an error' do
        expect{ config_hash.delete :k }.to raise_error(RuntimeError)
      end
    end

    context 'when freeze is false' do
      let(:options) { {freeze: false} }
      it 'unsets the method accessor as well as removing the value' do
        config_hash.delete :k
        expect(config_hash).to_not respond_to :k
        expect(config_hash[:k]).to be_nil
      end

      it 'converts strings to symbols' do
        config_hash.delete 'k'
        expect(config_hash).to_not respond_to :k
        expect(config_hash[:k]).to be_nil
      end
    end
  end
end