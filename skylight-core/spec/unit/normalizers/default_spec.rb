require 'spec_helper'

module Skylight
  describe "Normalizers", 'default', :agent do

    context 'valid events' do

      it 'keeps the notification name' do
        name, title, desc = normalize('app.request.rack', {})

        expect(name).to eq('app.request.rack')
        expect(title).to be_nil
        expect(desc).to be_nil
      end

      it 'grabs title from the payload' do
        name, title, desc = normalize('noise.gc', title: 'Garbage')

        expect(name).to eq('noise.gc')
        expect(title).to eq('Garbage')
        expect(desc).to be_nil
      end

      it 'grabs description from the payload' do
        name, title, desc = normalize('view.show', description: 'A view')

        expect(name).to eq('view.show')
        expect(title).to be_nil
        expect(desc).to eq('A view')
      end

      it 'keeps the payload' do
        name, title, desc = normalize('noise.gc', foo: "bar", title: "Junk")

        expect(name).to eq('noise.gc')
        expect(title).to eq('Junk')
        expect(desc).to be_nil
      end

    end

    context 'invalid events' do

      it 'rejects unknown events' do
        expect(normalize('foo.bar')).to eq(:skip)
      end

      it 'rejects unknown events prefixed with app' do
        expect(normalize('application.lul')).to eq(:skip)
      end

    end
  end
end
