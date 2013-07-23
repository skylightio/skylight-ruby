require 'spec_helper'

module Skylight
  describe Normalizers, 'default' do

    context 'valid events' do

      it 'keeps the notification name' do
        name, title, desc, annot = normalize('app.request.rack')

        name.should == 'app.request.rack'
        title.should be_nil
        desc.should be_nil
        annot.should == {}
      end

      it 'grabs title from the payload' do
        name, title, desc, annot = normalize('noise.gc', title: 'Garbage')

        name.should == 'noise.gc'
        title.should == 'Garbage'
        desc.should be_nil
        annot.should == {}
      end

      it 'grabs description from the payload' do
        name, title, desc, annot = normalize('view.show', description: 'A view')

        name.should == 'view.show'
        title.should be_nil
        desc.should == 'A view'
        annot.should == {}
      end

      it 'keeps the payload' do
        name, title, desc, annot = normalize('noise.gc', foo: "bar", title: "Junk")

        name.should == 'noise.gc'
        title.should == 'Junk'
        desc.should be_nil
        annot.should == { foo: "bar" }
      end

    end

    context 'invalid events' do

      it 'rejects unknown events' do
        normalize('foo.bar').should == :skip
      end

      it 'rejects unknown events prefixed with app' do
        normalize('application.lul').should == :skip
      end

    end
  end
end
