class Censo < ActiveRecord::Base

    attr_accessor :NIP, :grupo
    validates :NIP, :grupo, presence: true
  
end