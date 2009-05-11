class Forklib
  def self.extract(datafile, outputfolder)
    contents = IO.read(datafile)
    
    # extract the 16 byte header
    header = contents[0,16]
    
    # verify magic header
    magic = header[0,6]
    return :FAIL if magic != "SARCFV"
    
    # check for correct version number
    version = header[6,2]
    return :FAIL if version != "\001\001"
    
    # number of entries in index
    num_entries = header[8,4].unpack('I')[0]
    
    # offset of index
    index_offset = header[12,4].unpack('I')[0]
    
    # extract index from end of file
    index = contents[index_offset, contents.length-index_offset]
    
    # pull out structured index table
    index_table = []; i = 0
    num_entries.times do
      len = index[i, 1].unpack('C')[0]; i += 1
      name = index[i, len]; i += len+1 # ignore NULL termination
      offset = index[i, 4].unpack('I')[0]; i += 4
      size1 = index[i, 4].unpack('I')[0]; i += 4
      size2 = index[i, 4].unpack('I')[0]; i += 4
      
      # not sure why size is duplicated but they are always identical
      return :FAIL if size1 != size2
      
      index_table << [name, offset, size1]
    end
    
    Dir.mkdir(outputfolder) unless File::directory?(outputfolder)
    i = 0; # keep index with file so it can be repacked in the same order
           # probably not necessary but what the hell
    index_table.each do |name, offset, size|
      # really lame transform to keep filename intact
      sanitised_name = sprintf("%03d ", i) + name.gsub(':', '$').gsub('\\', '>')
      File.open(File.join(outputfolder, sanitised_name), "wb") do |file|
        file.write(contents[offset, size])
      end
      i += 1
    end
    return :WOO
  end
  
  def self.compact(inputfolder, outputfile)
    # find all files with index number
    files = Dir[File.join(inputfolder, "*")]
    files = files.select{|x| File.split(x)[1] =~ /^\d{3} /}
    files.map!{|x| [x, File.split(x)[1]]}.sort!
    
    num_entries = files.length
    
    # unsanitise file names and collect file contents
    file_sections = []
    # keep track of offset, start after header
    offset_accum = 16
    files.map! do |path, file|
      m = file.match(/^\d{3} (.*)/)
      sanitised_name = m[1]
      name = sanitised_name.gsub('$', ':').gsub('>', '\\')
      
      # extract information about file and add it to file_section
      temp = IO.read(path)
      file_length = temp.length
      file_sections << temp
      data = [path, file, name, offset_accum, file_length]
      offset_accum += file_length
      data
    end
    index_offset = offset_accum
    
    # write everything out in SAR format
    File.open(outputfile, 'wb') do |file|
      file.write("SARCFV")
      file.write("\001\001")
      file.write([num_entries].pack('I'))
      file.write([index_offset].pack('I'))
      file_sections.each{|x| file.write(x)}
      files.each do |path, filename, name, offset, length|
        file.write([name.length].pack('C'))
        file.write(name+"\000")
        file.write([offset].pack('I'))
        file.write([length].pack('I')*2)
      end
    end
  end
end

Shoes.app :title => 'Forklib GUI', :width => 400, :height => 600 do
  @extract_file = ''
  @extract_folder = ''
  
  @compact_folder = ''
  @compact_file = ''
  
  stack :width => 400, :height => 600 do
    # extract
    stack :width => 400, :height => 300 do
      background cadetblue
      para 'EXTRACT', :font => '26px', :underline => 'single'
      button 'Choose your data.sar file', :width => 300 do
        @extract_file = ask_open_file()
        @extract_file_disp.replace(@extract_file)
      end
      flow do
        para 'Chosen Input File: ', :font => '10px'
        @extract_file_disp = para '', :font => '10px'
      end
      button 'Choose a folder to extract into', :width => 300 do
        @extract_folder = ask_save_folder()
        @extract_folder_disp.replace(@extract_folder)
      end
      flow do
        para 'Chosen Output Folder: ', :font => '10px'
        @extract_folder_disp = para '', :font => '10px'
      end
      button 'GO!', :width => 300, :stroke => red do
        status = Forklib.extract(@extract_file, @extract_folder)
        if status == :FAIL 
          @extract_status.replace 'Extraction Failed'
        else
          @extract_status.replace 'Extraction Complete'
        end
      end
      flow do
        para 'Result: '
        @extract_status = para ''
      end
    end
    #compact
    stack :width => 400, :height => 300 do
      background coral
      para 'COMPACT', :font => '26px', :underline => 'single'
      button 'Choose the folder to compact', :width => 300 do
        @compact_folder = ask_open_folder()
        @compact_folder_disp.replace(@compact_folder)
      end
      flow do
        para 'Chosen Input Folder: ', :font => '10px'
        @compact_folder_disp = para '', :font => '10px'
      end
      button 'Choose a file to save as (data.sar)', :width => 300 do
        @compact_file = ask_open_file() #argh why doesn't this work
        @compact_file_disp.replace(@compact_file)
      end
      flow do
        para 'Chosen Output File: ', :font => '10px'
        @compact_file_disp = para '', :font => '10px'
      end
      button 'GO!', :width => 300, :stroke => red do
        status = Forklib.compact(@compact_folder, @compact_file)
        @extract_status.replace 'Compaction Complete'
      end
      flow do
        para 'Result: '
        @extract_status = para ''
      end
    end
  end
end