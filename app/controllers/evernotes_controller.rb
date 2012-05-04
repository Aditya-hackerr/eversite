require 'evernote'
require 'date'

class EvernotesController < ApplicationController
  def common
    link = CONFIG['header_links'].select { |link| add_trailing_slash(link['path']) == add_trailing_slash(request.path) }.first || not_found
    resource = link['resource']
    case resource['type']
    when 'notebook'
      @notes = get_notes_list(resource['name']) || not_found
      @title = link['text']
      return render 'index'
    when 'note'
      @note = get_note_by_guid(resource['guid']) || not_found
      return render 'show'
    else
      not_found
    end
  end

  def show
    created = DateTime.strptime(params[:created], '%s').strftime('%Y%m%dT%H%M%SZ')
    @note = get_note_by_created(created) || not_found
  end

  private

    def authenticate
      user_store_url = "https://#{CONFIG['evernote']['domain']}/edam/user"
      user_store = Evernote::UserStore.new(user_store_url, CONFIG['evernote']['config'])
      authentication = user_store.authenticate
      user, auth_token = authentication.user, authentication.authenticationToken
      note_store_url = "http://#{CONFIG['evernote']['domain']}/edam/note/#{user.shardId}"
      note_store = Evernote::NoteStore.new(note_store_url)
      return note_store, auth_token
    end

    @@note_store = @@auth_token = nil
    def note_store
      if @@note_store.nil?
        @@note_store, @@auth_token = authenticate
      end
      @@note_store
    end
    def auth_token
      if @@auth_token.nil?
        @@note_store, @@auth_token = authenticate
      end
      @@auth_token
    end

    def get_notes_list(notebook_name)
      notebook = note_store.listNotebooks(auth_token).select { |notebook| notebook.name.force_encoding('utf-8') == notebook_name }.first || not_found
      note_filter = Evernote::EDAM::NoteStore::NoteFilter.new(notebookGuid: notebook.guid,
        order: Evernote::EDAM::Type::NoteSortOrder::CREATED, ascending: false)
      notes = note_store.findNotes(auth_token, note_filter, 0, 1000).notes
      notes.map { |note| { title: note.title.force_encoding('utf-8'), created: note.created } }
    end

    CONTENT_REGEXP = /<en-note[^>]*?>(.+?)<\/en-note>/m

    def get_note_by_guid(guid)
      note = note_store.getNote(auth_token, guid, true, true, true, true) || not_found
      CONTENT_REGEXP =~ note.content
      { title: note.title.force_encoding('utf-8'), content: $1.force_encoding('utf-8') }
    end

    def get_note_by_created(created)
      note_filter = Evernote::EDAM::NoteStore::NoteFilter.new(words: "created:#{created}",
        order: Evernote::EDAM::Type::NoteSortOrder::CREATED, ascending: true)
      note = note_store.findNotes(auth_token, note_filter, 0, 1).notes.first || not_found
      get_note_by_guid(note.guid)
    end
end