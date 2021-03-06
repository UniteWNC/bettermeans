# BetterMeans - Work 2.0
# Copyright (C) 2006-2011  See readme for details and license#

require "digest/md5"

class Attachment < ActiveRecord::Base
  belongs_to :container, :polymorphic => true
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"

  validates_presence_of :filename, :author
  validates_length_of :filename, :maximum => 255
  validates_length_of :disk_filename, :maximum => 255

  after_validation :put_to_s3
  before_destroy   :delete_from_s3


  acts_as_event :title => :filename,
                :url => Proc.new {|o| {:controller => 'attachments', :action => 'download', :id => o.id, :filename => o.filename}}

  cattr_accessor :storage_path
  unloadable # Send unloadable so it will not be unloaded in development
  attr_accessor :s3_access_key_id, :s3_secret_acces_key, :s3_bucket, :s3_bucket

  @@storage_path = "#{RAILS_ROOT}/files"

  def validate # spec_me cover_me heckle_me
    if self.filesize > Setting.attachment_max_size.to_i.kilobytes
      errors.add(:base, :too_long, :count => Setting.attachment_max_size.to_i.kilobytes)
    end
  end

  def put_to_s3 # spec_me cover_me heckle_me
    if @temp_file && (@temp_file.size > 0)
      logger.debug("Uploading to #{RedmineS3::Connection.uri}/#{disk_filename}")
      RedmineS3::Connection.put(disk_filename, @temp_file.read)
      RedmineS3::Connection.publicly_readable!(disk_filename)
      md5 = Digest::MD5.new
      self.digest = md5.hexdigest
    end
    @temp_file = nil # so that the model's original after_save block skips writing to the fs
  end

  def delete_from_s3 # spec_me cover_me heckle_me
    if ENV['RACK_ENV'] == 'production'
      logger.debug("Deleting #{RedmineS3::Connection.uri}/#{disk_filename}")
      RedmineS3::Connection.delete(disk_filename)
    end
  end

  def file=(incoming_file) # spec_me cover_me heckle_me
    unless incoming_file.nil?
      @temp_file = incoming_file
      if @temp_file.size > 0
        self.filename = sanitize_filename(@temp_file.original_filename)
        self.disk_filename = Attachment.disk_filename(filename)
        self.content_type = @temp_file.content_type.to_s.chomp
        self.filesize = @temp_file.size
      end
    end
  end

  def file # spec_me cover_me heckle_me
    nil
  end

  # Copies the temporary file to its final location
  # and computes its MD5 hash
  def before_save # spec_me cover_me heckle_me
    logger.debug("entering before save")
    if @temp_file && (@temp_file.size > 0)
      logger.debug("saving '#{self.diskfile}'")
      md5 = Digest::MD5.new
      File.open(diskfile, "wb") do |f|
        buffer = ""
        while (buffer = @temp_file.read(8192))
          f.write(buffer)
          md5.update(buffer)
        end
      end
      self.digest = md5.hexdigest
    end
    # Don't save the content type if it's longer than the authorized length
    if self.content_type && self.content_type.length > 255
      self.content_type = nil
    end
  end

  # Deletes file on the disk
  def after_destroy # spec_me cover_me heckle_me
    File.delete(diskfile) if !filename.blank? && File.exist?(diskfile)
  end

  # Returns file's location on disk
  def diskfile # spec_me cover_me heckle_me
    "#{@@storage_path}/#{self.disk_filename}"
  end

  def increment_download # spec_me cover_me heckle_me
    increment!(:downloads)
  end

  def project # heckle_me
    container.project
  end

  def visible?(user=User.current) # heckle_me
    container.attachments_visible?(user)
  end

  def deletable?(user=User.current) # spec_me cover_me heckle_me
    container.attachments_deletable?(user)
  end

  def image? # spec_me cover_me heckle_me
    self.filename =~ /\.(jpe?g|gif|png)$/i
  end

  def is_text? # spec_me cover_me heckle_me
    Redmine::MimeType.is_type?('text', filename)
  end

  def is_diff? # spec_me cover_me heckle_me
    self.filename =~ /\.(patch|diff)$/i
  end

  # Returns true if the file is readable
  def readable? # spec_me cover_me heckle_me
    File.readable?(diskfile)
  end

  private

  def sanitize_filename(value) # cover_me heckle_me
    # get only the filename, not the whole path
    just_filename = value.gsub(/^.*(\\|\/)/, '')
    # NOTE: File.basename doesn't work right with Windows paths on Unix
    # INCORRECT: just_filename = File.basename(value.gsub('\\\\', '/'))

    # Finally, replace all non alphanumeric, hyphens or periods with underscore
    @filename = just_filename.gsub(/[^\w\.\-]/,'_')
  end

  # Returns an ASCII or hashed filename
  def self.disk_filename(filename) # cover_me heckle_me
    df = DateTime.now.strftime("%y%m%d%H%M%S") + "_"
    if filename =~ %r{^[a-zA-Z0-9_\.\-]*$}
      df << filename
    else
      df << Digest::MD5.hexdigest(filename)
      # keep the extension if any
      df << $1 if filename =~ %r{(\.[a-zA-Z0-9]+)$}
    end
    df
  end

end

