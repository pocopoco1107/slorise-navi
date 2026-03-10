# frozen_string_literal: true

require "digest"
require "net/http"
require "nokogiri"
require "uri"

# P-WORLD scraping tasks for importing shop and machine data.
# P-WORLD URL patterns:
#   Shop search:  https://www.p-world.co.jp/_machine/alkensaku.cgi?k={prefecture_name}&is_new_ver=1&page={page}
#   Machine list:  https://www.p-world.co.jp/_machine/t_machine.cgi?mode=slot_type&key={type}&start={offset}
#   New machines: https://www.p-world.co.jp/database/machine/introduce_calendar.cgi

module PworldScraper
  BASE_URL = "https://www.p-world.co.jp"
  USER_AGENT = "Mozilla/5.0 (compatible; SloSitteBot/1.0; +https://slositte.example.com)"
  REQUEST_INTERVAL = 2.5 # seconds between requests
  MAX_RETRIES = 3

  # Prefecture name => slug mapping used by P-WORLD search.
  # The search uses the Japanese prefecture name to find shops in that prefecture.
  PREFECTURE_SEARCH_NAMES = {
    "hokkaido"   => "北海道",
    "aomori"     => "青森県",
    "iwate"      => "岩手県",
    "miyagi"     => "宮城県",
    "akita"      => "秋田県",
    "yamagata"   => "山形県",
    "fukushima"  => "福島県",
    "ibaraki"    => "茨城県",
    "tochigi"    => "栃木県",
    "gunma"      => "群馬県",
    "saitama"    => "埼玉県",
    "chiba"      => "千葉県",
    "tokyo"      => "東京都",
    "kanagawa"   => "神奈川県",
    "niigata"    => "新潟県",
    "toyama"     => "富山県",
    "ishikawa"   => "石川県",
    "fukui"      => "福井県",
    "yamanashi"  => "山梨県",
    "nagano"     => "長野県",
    "gifu"       => "岐阜県",
    "shizuoka"   => "静岡県",
    "aichi"      => "愛知県",
    "mie"        => "三重県",
    "shiga"      => "滋賀県",
    "kyoto"      => "京都府",
    "osaka"      => "大阪府",
    "hyogo"      => "兵庫県",
    "nara"       => "奈良県",
    "wakayama"   => "和歌山県",
    "tottori"    => "鳥取県",
    "shimane"    => "島根県",
    "okayama"    => "岡山県",
    "hiroshima"  => "広島県",
    "yamaguchi"  => "山口県",
    "tokushima"  => "徳島県",
    "kagawa"     => "香川県",
    "ehime"      => "愛媛県",
    "kochi"      => "高知県",
    "fukuoka"    => "福岡県",
    "saga"       => "佐賀県",
    "nagasaki"   => "長崎県",
    "kumamoto"   => "熊本県",
    "oita"       => "大分県",
    "miyazaki"   => "宮崎県",
    "kagoshima"  => "鹿児島県",
    "okinawa"    => "沖縄県"
  }.freeze

  # Slot type keys used in P-WORLD machine search
  SLOT_TYPE_KEYS = %w[AT NORMAL RT aRT over_6.5number].freeze

  class << self
    # Fetch a URL with retry logic and rate limiting.
    # Returns Nokogiri::HTML document or nil on failure.
    def fetch_page(url, encoding: nil)
      uri = URI.parse(url)
      retries = 0

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 15
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "text/html"
        request["Accept-Language"] = "ja,en;q=0.5"

        response = http.request(request)

        case response.code.to_i
        when 200
          body = response.body
          # Handle EUC-JP encoded pages (older P-WORLD pages)
          if encoding
            body = body.force_encoding(encoding).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          elsif body.force_encoding("UTF-8").valid_encoding?
            # Already UTF-8, do nothing
          else
            # Try EUC-JP as fallback (many P-WORLD pages use it)
            body = body.force_encoding("EUC-JP").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          end
          Nokogiri::HTML(body)
        when 301, 302
          # Follow redirect
          new_url = response["Location"]
          new_url = "#{uri.scheme}://#{uri.host}#{new_url}" if new_url.start_with?("/")
          fetch_page(new_url, encoding: encoding)
        else
          puts "  WARNING: HTTP #{response.code} for #{url}"
          nil
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
        retries += 1
        if retries <= MAX_RETRIES
          puts "  RETRY #{retries}/#{MAX_RETRIES}: #{e.class} - #{e.message}"
          sleep(REQUEST_INTERVAL * retries)
          retry
        else
          puts "  ERROR: Failed after #{MAX_RETRIES} retries: #{e.message}"
          nil
        end
      rescue StandardError => e
        puts "  ERROR: #{e.class} - #{e.message}"
        nil
      end
    end

    # Generate a URL-safe slug from a shop's P-WORLD href path.
    # e.g., "/tokyo/maruhan-shinjuku.htm" => "maruhan-shinjuku"
    def extract_shop_slug_from_href(href)
      return nil if href.blank?

      # Extract the filename part: "/tokyo/maruhan-shinjuku.htm" => "maruhan-shinjuku"
      filename = href.split("/").last&.gsub(/\.htm$/, "")
      filename.presence
    end

    # Parse slot rate info from P-WORLD "detail-kashidama" element.
    # Returns { slot_rates: [...], exchange_rate: symbol }
    # Examples:
    #   "1000円/46枚" → 20スロ等価  "1000円/200枚" → 5スロ
    #   "1000円/178枚" → 5.6枚交換   "1000円/92枚" → 10スロ
    #   "1000円/160枚" → 非等価
    def parse_slot_rates(kashidama_el)
      return { slot_rates: [], exchange_rate: :unknown_rate } unless kashidama_el

      slot_spans = kashidama_el.css("span.iconSlot").map { |s| s.text.strip }
      rates = []
      exchange = :unknown_rate

      slot_spans.each do |span|
        if span =~ /(\d+)円\/(\d+)枚/
          yen = $1.to_i
          coins = $2.to_i
          rate_per_coin = yen.to_f / coins

          case coins
          when 46..50
            rates << "20スロ"
            exchange = :equal_rate # 等価 (1000/46 ≒ 21.7円, ほぼ等価)
          when 89..96
            rates << "10スロ"
          when 170..185
            rates << "5スロ"
            exchange = :rate_56 if exchange == :unknown_rate # 5.6枚交換相当
          when 196..210
            rates << "5スロ"
            exchange = :rate_50 if exchange == :unknown_rate # 5.0枚交換
          when 150..169
            rates << "5スロ"
            exchange = :non_equal if exchange == :unknown_rate
          when 370..420
            rates << "2スロ"
          when 900..1100
            rates << "1スロ"
          else
            # Unknown rate, try to classify by per-coin value
            if rate_per_coin >= 18
              rates << "20スロ"
            elsif rate_per_coin >= 8
              rates << "10スロ"
            elsif rate_per_coin >= 4
              rates << "5スロ"
            elsif rate_per_coin >= 1.5
              rates << "2スロ"
            else
              rates << "1スロ"
            end
            exchange = :non_equal if exchange == :unknown_rate
          end
        end
      end

      { slot_rates: rates.uniq, exchange_rate: exchange }
    end

    # Parse service/facility icons from hallDetail.
    # Returns array of facility names.
    ICON_MAP = {
      "wifi" => "Wi-Fi",
      "sp_charge" => "充電器",
      "inner_smoking_room" => "屋内喫煙室",
      "outdoor_smoking_space" => "屋外喫煙",
      "heating_smoking_area" => "加熱式たばこ",
      "prevent_infection" => "感染症対策",
      "self_declare" => "自己申告",
      "disaster_stock" => "災害対応",
      "dedama_icon" => "出玉公開"
    }.freeze

    def parse_facilities(hall)
      hall.css("td.service img").filter_map { |img|
        key = img["src"]&.split("/")&.last&.split(".")&.first
        ICON_MAP[key]
      }.uniq
    end

    # Import shops for a single prefecture.
    # Returns the count of imported/updated shops.
    def import_shops_for_prefecture(prefecture)
      slug = prefecture.slug
      pref_name = PREFECTURE_SEARCH_NAMES[slug]

      unless pref_name
        puts "  WARNING: No P-WORLD search name mapping for slug '#{slug}', skipping."
        return 0
      end

      puts "Importing #{pref_name} (#{slug})..."

      # URL-encode the prefecture name for the search query
      encoded_name = URI.encode_www_form_component(pref_name)

      page = 0
      total_imported = 0
      total_updated = 0
      total_on_pworld = nil

      loop do
        url = "#{BASE_URL}/_machine/alkensaku.cgi?k=#{encoded_name}&is_new_ver=1&page=#{page}"
        doc = fetch_page(url, encoding: "EUC-JP")

        unless doc
          puts "  Failed to fetch page #{page}, stopping pagination."
          break
        end

        # On first page, extract the total count
        if page == 0
          count_text = doc.at_css("meta[name='description']")&.attr("content") || ""
          if count_text =~ /該当(\d+)店舗/
            total_on_pworld = $1.to_i
            puts "  P-WORLD reports #{total_on_pworld} shops for #{pref_name}"
          end
        end

        # Parse shop entries from hallDetail divs
        hall_details = doc.css("div.hallDetail")

        if hall_details.empty?
          puts "  No more shops found on page #{page}."
          break
        end

        hall_details.each do |hall|
          begin
            # Extract shop name and link
            link_el = hall.at_css("a.detail-hallLink")
            next unless link_el

            shop_name = link_el.text.strip
            shop_href = link_el["href"]
            shop_slug = extract_shop_slug_from_href(shop_href)

            next if shop_slug.blank? || shop_name.blank?

            # Extract address
            address_div = hall.at_css("div.detail-address")
            address = nil
            if address_div
              # Get text content, excluding child elements like the "周辺" button
              address_text = address_div.children.select { |c| c.text? }.map(&:text).join.strip
              address = address_text.presence
            end

            # Extract slot rate and exchange rate info
            kashidama = hall.at_css("p.detail-kashidama")
            rate_info = parse_slot_rates(kashidama)

            # Extract facilities
            facilities = parse_facilities(hall)

            # Build P-WORLD URL
            pworld_url = shop_href&.start_with?("http") ? shop_href : "#{BASE_URL}#{shop_href}" if shop_href.present?

            # Create or update the shop
            shop = Shop.find_or_initialize_by(slug: shop_slug)
            shop.name = shop_name
            shop.prefecture = prefecture
            shop.address = address if address.present?
            shop.slot_rates = rate_info[:slot_rates] if rate_info[:slot_rates].any?
            shop.exchange_rate = rate_info[:exchange_rate] if rate_info[:exchange_rate] != :unknown_rate
            shop.notes = facilities.join("、") if facilities.any?
            shop.pworld_url = pworld_url if pworld_url.present?

            if shop.new_record?
              shop.save!
              total_imported += 1
            elsif shop.changed?
              shop.save!
              total_updated += 1
            end
          rescue ActiveRecord::RecordInvalid => e
            puts "  WARNING: Could not save shop '#{shop_name}': #{e.message}"
          rescue StandardError => e
            puts "  WARNING: Error processing shop entry: #{e.message}"
          end
        end

        page += 1
        # Safety check: P-WORLD shows 50 per page
        break if hall_details.size < 50

        sleep(REQUEST_INTERVAL)
      end

      shop_count = prefecture.shops.count
      puts "  Done: #{pref_name} - #{total_imported} new, #{total_updated} updated (#{shop_count} total in DB)"
      total_imported
    end

    # Import machine models from P-WORLD slot type listing pages.
    def import_slot_machines
      puts "Importing slot machine models from P-WORLD..."

      total_imported = 0

      SLOT_TYPE_KEYS.each do |type_key|
        puts "  Fetching type: #{type_key}..."
        offset = 0

        loop do
          url = "#{BASE_URL}/_machine/t_machine.cgi?mode=slot_type&key=#{URI.encode_www_form_component(type_key)}&start=#{offset}"
          doc = fetch_page(url, encoding: "EUC-JP")

          unless doc
            puts "    Failed to fetch page at offset #{offset}, stopping."
            break
          end

          # Find machine rows: each has td.title, td.type, td.maker
          titles = doc.css("td.title")

          if titles.empty?
            break
          end

          titles.each do |title_td|
            begin
              row = title_td.parent
              next unless row

              # Machine name from the link inside td.title
              name_link = title_td.at_css("a[href*='/machine/database/']")
              next unless name_link

              machine_name = name_link.text.strip
              next if machine_name.blank?

              # Machine type from td.type
              type_td = row.at_css("td.type")
              type_text = type_td&.text&.strip || ""

              # Maker from td.maker
              maker_td = row.at_css("td.maker")
              maker_name = maker_td&.text&.strip

              # Generate slug from machine name
              slug = machine_name
                .gsub(/\s+/, "-")
                .gsub(/[^\p{L}\p{N}\-]/, "")
                .downcase
                .truncate(100, omission: "")

              # Avoid empty slugs
              next if slug.blank?

              # Map P-WORLD type to our spec_type
              spec_type = case type_text
                          when "NORMAL" then :type_a
                          when "AT" then :type_at
                          when "ART", "aRT" then :type_art
                          when "RT" then :type_a_plus_at
                          else :type_at
                          end

              model = MachineModel.find_or_initialize_by(slug: slug)
              if model.new_record?
                model.name = machine_name
                model.maker = maker_name
                model.machine_type = :slot
                model.spec_type = spec_type
                model.save!
                total_imported += 1
              elsif maker_name.present? && model.maker.blank?
                model.update!(maker: maker_name)
              end
            rescue ActiveRecord::RecordInvalid => e
              puts "    WARNING: Could not save machine '#{machine_name}': #{e.message}"
            rescue StandardError => e
              puts "    WARNING: Error processing machine entry: #{e.message}"
            end
          end

          offset += titles.size
          # P-WORLD typically shows 20 machines per page
          break if titles.size < 20

          sleep(REQUEST_INTERVAL)
        end

        sleep(REQUEST_INTERVAL)
      end

      puts "  Done: #{total_imported} new machine models imported (#{MachineModel.count} total in DB)"
      total_imported
    end

    # Scrape the over_6.5number (smart slot) listing from P-WORLD and flag matching machines.
    # Also flags machines with Ｌ prefix or スマスロ keyword.
    # Returns the number of machines flagged.
    def flag_smart_slots
      puts "Flagging smart slot machines from P-WORLD over_6.5number listing..."

      pworld_smart_names = Set.new
      offset = 0

      loop do
        url = "#{BASE_URL}/_machine/t_machine.cgi?mode=slot_type&key=#{URI.encode_www_form_component('over_6.5number')}&start=#{offset}"
        doc = fetch_page(url, encoding: "EUC-JP")

        unless doc
          puts "  Failed to fetch page at offset #{offset}, stopping."
          break
        end

        titles = doc.css("td.title")
        break if titles.empty?

        titles.each do |title_td|
          name_link = title_td.at_css("a[href*='/machine/database/']")
          next unless name_link

          machine_name = name_link.text.strip
          next if machine_name.blank?

          pworld_smart_names << machine_name
        end

        offset += titles.size
        break if titles.size < 20

        sleep(REQUEST_INTERVAL)
      end

      puts "  Found #{pworld_smart_names.size} smart slot names from P-WORLD"

      # Build a slug lookup for matching
      pworld_smart_slugs = pworld_smart_names.map do |name|
        name.gsub(/\s+/, "-").gsub(/[^\p{L}\p{N}\-]/, "").downcase.truncate(100, omission: "")
      end.to_set

      # Flag by P-WORLD slug match
      flagged_by_pworld = 0
      MachineModel.where(is_smart_slot: false).find_each do |m|
        if pworld_smart_slugs.include?(m.slug)
          m.update_column(:is_smart_slot, true)
          flagged_by_pworld += 1
        end
      end
      puts "  Flagged by P-WORLD match: #{flagged_by_pworld}"

      # Flag by name patterns (Ｌ prefix, L prefix, スマスロ keyword)
      flagged_by_name = 0
      MachineModel.where(is_smart_slot: false).find_each do |m|
        if m.name.match?(/\AＬ/) || m.name.match?(/\AL[^a-z]/) || m.name.match?(/スマスロ/)
          m.update_column(:is_smart_slot, true)
          flagged_by_name += 1
        end
      end
      puts "  Flagged by name pattern: #{flagged_by_name}"

      total = MachineModel.where(is_smart_slot: true).count
      puts "  Total smart slot machines: #{total}"
      total
    end

    # Refresh installed machines for a shop (sync: add new, remove stale).
    # Returns { added: N, removed: N }
    def refresh_machines_for_shop(shop)
      pref_slug = shop.prefecture.slug
      shop_slug = shop.slug
      url = "#{BASE_URL}/#{pref_slug}/#{shop_slug}.htm"

      doc = fetch_page(url, encoding: "EUC-JP")
      return { added: 0, removed: 0 } unless doc

      current_slugs = Set.new
      added = 0

      doc.css("a[href*='/machine/database/']").each do |link|
        machine_name = link.text.strip
        next if machine_name.blank?
        next if MachineModel.pachinko_name?(machine_name)

        slug = machine_name
          .gsub(/\s+/, "-")
          .gsub(/[^\p{L}\p{N}\-]/, "")
          .downcase
          .truncate(100, omission: "")
        next if slug.blank?

        current_slugs << slug

        machine = MachineModel.find_or_initialize_by(slug: slug)
        if machine.new_record?
          machine.name = machine_name
          machine.machine_type = :slot
          machine.spec_type = :type_at
          machine.active = true
          machine.save!
        elsif !machine.active?
          machine.update!(active: true)
        end

        smm = ShopMachineModel.find_or_initialize_by(shop: shop, machine_model: machine)
        if smm.new_record?
          smm.save!
          added += 1
        end
      rescue ActiveRecord::RecordInvalid
        # Skip duplicates
      end

      # Remove stale links (machines no longer on the P-WORLD page)
      existing_links = shop.shop_machine_models.includes(:machine_model)
      removed = 0
      existing_links.each do |smm|
        unless current_slugs.include?(smm.machine_model.slug)
          smm.destroy!
          removed += 1
        end
      end

      { added: added, removed: removed }
    end

    # Import installed machines for a single shop.
    # Scrapes the shop's P-WORLD page to find currently installed slot machines.
    # Returns count of newly linked machines.
    def import_machines_for_shop(shop)
      # P-WORLD shop page URL pattern: /{prefecture_slug}/{shop_slug}.htm
      pref_slug = shop.prefecture.slug
      shop_slug = shop.slug
      url = "#{BASE_URL}/#{pref_slug}/#{shop_slug}.htm"

      doc = fetch_page(url, encoding: "EUC-JP")
      return 0 unless doc

      linked_count = 0

      # P-WORLD shop pages have machine lists in tables/divs
      # Look for slot machine section links, skip pachinko
      doc.css("a[href*='/machine/database/']").each do |link|
        machine_name = link.text.strip
        next if machine_name.blank?

        # Use the model-level pachinko filter (includes PF/CR patterns)
        next if MachineModel.pachinko_name?(machine_name)

        # Generate slug matching our import format
        slug = machine_name
          .gsub(/\s+/, "-")
          .gsub(/[^\p{L}\p{N}\-]/, "")
          .downcase
          .truncate(100, omission: "")

        next if slug.blank?

        # Find or create the machine (mark as active since it's currently installed)
        machine = MachineModel.find_or_initialize_by(slug: slug)
        if machine.new_record?
          machine.name = machine_name
          machine.machine_type = :slot
          machine.spec_type = :type_at
          machine.active = true
          machine.save!
        elsif !machine.active?
          machine.update!(active: true)
        end

        # Create the shop-machine association
        smm = ShopMachineModel.find_or_initialize_by(shop: shop, machine_model: machine)
        if smm.new_record?
          smm.save!
          linked_count += 1
        end
      rescue ActiveRecord::RecordInvalid => e
        # Skip duplicates silently
      end

      linked_count
    end

    # MD5 hash => digit mapping for P-WORLD number images.
    # The unit counts are rendered as obfuscated GIF images (one per digit).
    # Each digit always produces the same binary content regardless of filename,
    # so we can identify digits by their MD5 hash.
    DIGIT_IMAGE_HASHES = {
      "eea0a8b72a8e48fec333a70d6177fb5f" => "1",
      "8ddd74ece3496cef7ed88f50d1e61fe5" => "0",
      "ffb7b86da3dd3bad52f932d6df62ffed" => "8",
      "f36c62154cc67748ac8add0873ccfe74" => "3",
      "a4a1f76e363b06da2e7ca37f9270e453" => "6",
      "58dc98a1774c8614c399dd1f4e3b97cd" => "2",
      "d96268465d993d7c6de7ebd0d2dc5560" => "7",
      "287c597b517cb3bf4413fc643188a045" => "5",
      "67bb79d533a000dec3fd2707c93f24c7" => "9",
      "2a3601fe5109943f2e14f20b11fa828b" => "4"
    }.freeze

    # MD5 of the "台" suffix image (always appears last, not a digit)
    UNIT_SUFFIX_HASH = "872bb600682e141397e3813492f9c10a"

    # Download a single image and return its binary content.
    # Uses the same retry/timeout logic as fetch_page.
    def fetch_image(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "image/gif, image/*"

      response = http.request(request)
      response.code.to_i == 200 ? response.body : nil
    rescue StandardError
      nil
    end

    # Decode digit images from a shop page into a hash { image_src => digit_string }.
    # Downloads each unique number image and maps it via MD5 hash.
    # Returns nil if decoding fails.
    def build_digit_map(doc)
      # Collect all unique number image URLs (excluding the known 台 suffix)
      img_srcs = Set.new
      doc.css('li[data-machine-type="S"] span img[src*="/number/"]').each do |img|
        img_srcs << img["src"]
      end

      return nil if img_srcs.empty?

      digit_map = {}
      img_srcs.each do |src|
        image_url = "#{BASE_URL}#{src}"
        image_data = fetch_image(image_url)
        next unless image_data

        md5 = Digest::MD5.hexdigest(image_data)

        if md5 == UNIT_SUFFIX_HASH
          digit_map[src] = :suffix # "台" character
        elsif DIGIT_IMAGE_HASHES.key?(md5)
          digit_map[src] = DIGIT_IMAGE_HASHES[md5]
        else
          # Unknown image - log but don't fail
          puts "    WARNING: Unknown number image hash #{md5} for #{src}"
          digit_map[src] = nil
        end
      end

      digit_map
    end

    # Scrape unit counts for all slot machines at a shop.
    # Downloads the shop page, builds a digit map from number images,
    # then decodes each machine's unit count.
    # Returns { updated: N, skipped: N, machines: { slug => count } }
    def scrape_unit_counts_for_shop(shop)
      pref_slug = shop.prefecture.slug
      shop_slug = shop.slug
      url = "#{BASE_URL}/#{pref_slug}/#{shop_slug}.htm"

      doc = fetch_page(url, encoding: "EUC-JP")
      return nil unless doc

      slot_items = doc.css('li[data-machine-type="S"]')
      return { updated: 0, skipped: 0, machines: {} } if slot_items.empty?

      # Build digit map by downloading the number images for this page
      digit_map = build_digit_map(doc)
      return nil unless digit_map

      updated = 0
      skipped = 0
      machines = {}

      slot_items.each do |li|
        name_el = li.at_css("._pw-machine-item-machineName a")
        next unless name_el

        machine_name = name_el.text.strip
        next if machine_name.blank?
        next if MachineModel.pachinko_name?(machine_name)

        # Decode unit count from digit images
        imgs = li.css('span img[src*="/number/"]')
        digits = []
        imgs.each do |img|
          src = img["src"]
          mapped = digit_map[src]
          next if mapped == :suffix # Skip "台"
          next if mapped.nil?       # Skip unknown
          digits << mapped
        end

        next if digits.empty?

        unit_count = digits.join.to_i
        next if unit_count == 0

        # Find the matching machine slug
        slug = machine_name
          .gsub(/\s+/, "-")
          .gsub(/[^\p{L}\p{N}\-]/, "")
          .downcase
          .truncate(100, omission: "")
        next if slug.blank?

        machines[slug] = unit_count

        # Update the ShopMachineModel record
        machine = MachineModel.find_by(slug: slug)
        next unless machine

        smm = ShopMachineModel.find_by(shop: shop, machine_model: machine)
        if smm
          smm.update!(unit_count: unit_count)
          updated += 1
        else
          skipped += 1
        end
      end

      { updated: updated, skipped: skipped, machines: machines }
    end

    # Scrape shop detail page for all available info.
    # Extracts: machine counts, business hours, slot rates, exchange rate,
    #           facilities, pworld_url.
    # Returns a hash of the parsed data, or nil if the page couldn't be fetched.
    def scrape_shop_details(shop)
      pref_slug = shop.prefecture.slug
      shop_slug = shop.slug
      url = "#{BASE_URL}/#{pref_slug}/#{shop_slug}.htm"

      doc = fetch_page(url, encoding: "EUC-JP")
      return nil unless doc

      data = { pworld_url: url }
      page_text = doc.text

      # Parse the basic info section
      # Labels are in bold or colored cells, followed by value text
      # We scan the full page text for known patterns

      # 台数: "パチンコ 439台 / スロット 439台"
      if page_text =~ /パチンコ[　\s]*(\d+)台/
        pachinko_count = $1.to_i
      end
      if page_text =~ /スロット[　\s]*(\d+)台/
        data[:slot_machines] = $1.to_i
      end
      if pachinko_count && data[:slot_machines]
        data[:total_machines] = pachinko_count + data[:slot_machines]
      elsif data[:slot_machines]
        data[:total_machines] = data[:slot_machines]
      end

      # 遊技料金: "パチスロ：[1000円/46枚]" or "[1000円/47枚] [1000円/200枚]"
      slot_rate_matches = page_text.scan(/\[(\d+)円\/(\d+)枚\]/)
      if slot_rate_matches.any?
        rates = []
        exchange = nil
        slot_rate_matches.each do |yen_s, coins_s|
          yen = yen_s.to_i
          coins = coins_s.to_i
          rate_per_coin = yen.to_f / coins

          case coins
          when 46..50
            rates << "20スロ"
            exchange ||= :equal_rate
          when 89..96
            rates << "10スロ"
          when 170..185
            rates << "5スロ"
            exchange ||= :rate_56
          when 196..210
            rates << "5スロ"
            exchange ||= :rate_50
          when 150..169
            rates << "5スロ"
            exchange ||= :non_equal
          when 370..420
            rates << "2スロ"
          when 900..1100
            rates << "1スロ"
          else
            if rate_per_coin >= 18
              rates << "20スロ"
            elsif rate_per_coin >= 8
              rates << "10スロ"
            elsif rate_per_coin >= 4
              rates << "5スロ"
            elsif rate_per_coin >= 1.5
              rates << "2スロ"
            else
              rates << "1スロ"
            end
            exchange ||= :non_equal
          end
        end
        data[:slot_rates] = rates.uniq if rates.any?
        data[:exchange_rate] = exchange if exchange
      end

      # テーブルから各種情報を取得
      doc.css('td[bgcolor="#6699FF"]').each do |label_td|
        label = label_td.text.gsub(/[\s　]+/, "").strip
        value_td = label_td.next_element
        next unless value_td
        value = value_td.text.gsub(/[　\s]+/, " ").strip

        case label
        when "営業時間"
          data[:business_hours] = value if value.present?
        when "電話"
          data[:phone_number] = value if value.present?
        when "駐車場"
          if (m = value.match(/(\d[\d,]+)\s*台/))
            data[:parking_spaces] = m[1].delete(",").to_i
          end
        when "朝の入場"
          data[:morning_entry] = value if value.present?
        when "交通"
          # 「【店舗地図】」だけの場合は無視
          data[:access_info] = value if value.present? && value != "【店舗地図】"
        when "特徴"
          data[:features] = value if value.present?
        end
      end

      # 店内環境・喫煙環境から設備情報を取得
      facilities = []
      if page_text.include?("Wi-Fi")
        facilities << "Wi-Fi"
      end
      if page_text.include?("充電器") || page_text.include?("携帯充電")
        facilities << "充電器"
      end
      if page_text.include?("屋内喫煙室")
        facilities << "屋内喫煙室"
      end
      # 「加熱式たばこプレイエリア」= 遊技中に加熱式たばこOK
      # 「加熱式たばこ」のみ = 喫煙室で加熱式たばこ可（プレイ中は不可）
      if page_text.include?("加熱式たばこプレイエリア")
        facilities << "加熱式たばこ遊技OK"
      elsif page_text.include?("加熱式たばこ")
        facilities << "加熱式たばこ喫煙室"
      end
      if page_text.include?("出玉公開") || page_text.include?("出玉情報")
        facilities << "出玉公開"
      end
      data[:facilities] = facilities if facilities.any?

      # Update the shop record with found data
      updated = false

      if data[:slot_machines] && shop.slot_machines != data[:slot_machines]
        shop.slot_machines = data[:slot_machines]
        updated = true
      end
      if data[:total_machines] && shop.total_machines != data[:total_machines]
        shop.total_machines = data[:total_machines]
        updated = true
      end
      if data[:business_hours] && shop.business_hours != data[:business_hours]
        shop.business_hours = data[:business_hours]
        updated = true
      end
      # レート・換金率は既存データがない場合のみ上書き
      if data[:slot_rates] && (shop.slot_rates.blank? || shop.slot_rates.empty?)
        shop.slot_rates = data[:slot_rates]
        updated = true
      end
      if data[:exchange_rate] && shop.exchange_rate == "unknown_rate"
        shop.exchange_rate = data[:exchange_rate]
        updated = true
      end
      # 設備情報は詳細ページの方が正確なので常に上書き
      if data[:facilities]&.any?
        shop.notes = data[:facilities].join("、")
        updated = true
      end
      if data[:pworld_url] && shop.pworld_url != data[:pworld_url]
        shop.pworld_url = data[:pworld_url]
        updated = true
      end
      if data[:phone_number] && shop.phone_number != data[:phone_number]
        shop.phone_number = data[:phone_number]
        updated = true
      end
      if data[:parking_spaces] && shop.parking_spaces != data[:parking_spaces]
        shop.parking_spaces = data[:parking_spaces]
        updated = true
      end
      if data[:morning_entry] && shop.morning_entry != data[:morning_entry]
        shop.morning_entry = data[:morning_entry]
        updated = true
      end
      if data[:access_info] && shop.access_info != data[:access_info]
        shop.access_info = data[:access_info]
        updated = true
      end
      if data[:features] && shop.features != data[:features]
        shop.features = data[:features]
        updated = true
      end

      shop.save! if updated

      data
    rescue ActiveRecord::RecordInvalid => e
      puts "  WARNING: Could not update shop '#{shop.name}': #{e.message}"
      nil
    end

    # Import new/upcoming machines from the schedule page.
    def import_new_machines_from_schedule
      puts "Importing new machine models from P-WORLD schedule..."

      url = "#{BASE_URL}/database/machine/introduce_calendar.cgi"
      doc = fetch_page(url)

      unless doc
        puts "  ERROR: Failed to fetch schedule page."
        return 0
      end

      total_imported = 0

      # Each machine is in a machineList-item
      doc.css("li.machineList-item").each do |item|
        begin
          # Machine name
          title_el = item.at_css("p.machineList-item-title a")
          next unless title_el

          machine_name = title_el.text.strip
          next if machine_name.blank?

          # Machine type (パチンコ or パチスロ)
          type_el = item.at_css("p.machineList-item-type")
          type_text = type_el&.text&.strip || ""

          # Maker
          maker_el = item.at_css("p.machineList-item-maker a")
          maker_name = maker_el&.text&.strip

          # Spec info from memo
          memo_el = item.at_css("p.machineList-item-memo")
          memo_text = memo_el&.text&.strip || ""

          # Generate slug
          slug = machine_name
            .gsub(/\s+/, "-")
            .gsub(/[^\p{L}\p{N}\-]/, "")
            .downcase
            .truncate(100, omission: "")

          next if slug.blank?

          # Determine machine_type
          machine_type = if type_text.include?("パチスロ") || type_text.include?("スロット")
                           :slot
                         else
                           :pachislot
                         end

          model = MachineModel.find_or_initialize_by(slug: slug)
          if model.new_record?
            model.name = machine_name
            model.maker = maker_name
            model.machine_type = machine_type
            model.spec_type = :type_at # Default; schedule page doesn't always specify
            model.save!
            total_imported += 1
          end
        rescue ActiveRecord::RecordInvalid => e
          puts "  WARNING: Could not save machine '#{machine_name}': #{e.message}"
        rescue StandardError => e
          puts "  WARNING: Error processing machine: #{e.message}"
        end
      end

      puts "  Done: #{total_imported} new machine models imported from schedule"
      total_imported
    end

    # Fetch pworld_machine_id from the type listing pages.
    # Matches machine names from the list to existing DB records by slug.
    # Returns the number of machines updated.
    def fetch_machine_ids
      puts "Fetching pworld_machine_id from P-WORLD type listings..."

      total_updated = 0
      seen_ids = Set.new

      SLOT_TYPE_KEYS.each do |type_key|
        puts "  Type: #{type_key}..."
        offset = 0

        loop do
          url = "#{BASE_URL}/_machine/t_machine.cgi?mode=slot_type&key=#{URI.encode_www_form_component(type_key)}&start=#{offset}"
          doc = fetch_page(url, encoding: "EUC-JP")

          unless doc
            puts "    Failed to fetch page at offset #{offset}, stopping."
            break
          end

          titles = doc.css("td.title")
          break if titles.empty?

          titles.each do |title_td|
            name_link = title_td.at_css("a")
            next unless name_link

            href = name_link["href"].to_s
            next unless href =~ /\/machine\/database\/(\d+)/

            pworld_id = $1.to_i
            next if seen_ids.include?(pworld_id)
            seen_ids << pworld_id

            machine_name = name_link.text.strip
            next if machine_name.blank?

            slug = machine_name
              .gsub(/\s+/, "-")
              .gsub(/[^\p{L}\p{N}\-]/, "")
              .downcase
              .truncate(100, omission: "")
            next if slug.blank?

            machine = MachineModel.find_by(slug: slug)
            if machine && machine.pworld_machine_id.nil?
              machine.update_column(:pworld_machine_id, pworld_id)
              total_updated += 1
            end
          rescue StandardError => e
            puts "    WARNING: #{e.message}"
          end

          offset += titles.size
          break if titles.size < 20

          sleep(REQUEST_INTERVAL)
        end

        sleep(REQUEST_INTERVAL)
      end

      puts "  Done: #{total_updated} machines got pworld_machine_id"
      puts "  Total with ID: #{MachineModel.where.not(pworld_machine_id: nil).count}"
      total_updated
    end

    # Scrape machine detail page from P-WORLD.
    # Extracts: generation, payout rates, introduced_on, image_url, type_detail, certification_number.
    # Returns a hash of parsed data, or nil on failure.
    def scrape_machine_detail(machine)
      return nil unless machine.pworld_machine_id

      url = "#{BASE_URL}/machine/database/#{machine.pworld_machine_id}"
      doc = fetch_page(url)
      return nil unless doc

      data = {}

      # Parse kisyuInfo grid rows
      info = doc.at_css("div.kisyuInfo")
      if info
        info.css("table.kisyuInfo-grid > tr").each do |tr|
          text = tr.text.gsub(/[\s　]+/, " ").strip

          case text
          when /タイプ[　\s]*[：:]\s*(.+)/
            type_text = $1.strip
            data[:type_detail] = type_text unless data[:type_detail]

            # Extract generation from type text
            if type_text =~ /([\d.]+号機)/
              data[:generation] = $1
            end
          when /機械割[　\s]*[：:]\s*([\d.]+)[%％]\s*[～〜~]\s*([\d.]+)/
            data[:payout_rate_min] = $1.to_f
            data[:payout_rate_max] = $2.to_f
          when /検定番号[　\s]*[：:]\s*(\S+)/
            cert = $1.strip
            data[:certification_number] = cert if cert.present? && cert.length > 1
          when /導入開始[　\s]*[：:].*?(\d{4})年(\d{2})月(\d{2})日/
            begin
              data[:introduced_on] = Date.new($1.to_i, $2.to_i, $3.to_i)
            rescue ArgumentError
              # invalid date, skip
            end
          end
        end
      end

      # Extract smart slot tag
      tags = doc.css("span.kisyuTag-slotType").map { |t| t.text.strip }
      data[:is_smart_slot] = tags.include?("スマスロ")

      # Extract image URL
      img = doc.at_css("img[src*='machines']")
      if img && img["src"].present?
        src = img["src"]
        src = "https://idn.p-world.co.jp#{src}" if src.start_with?("/")
        data[:image_url] = src
      end

      # Update machine record
      updated = false
      %i[generation payout_rate_min payout_rate_max introduced_on image_url type_detail certification_number].each do |field|
        if data[field].present? && machine.send(field).blank?
          machine.send("#{field}=", data[field])
          updated = true
        end
      end

      # Update is_smart_slot if we got a positive signal and it is not already set
      if data[:is_smart_slot] && !machine.is_smart_slot?
        machine.is_smart_slot = true
        updated = true
      end

      machine.save! if updated

      data
    rescue ActiveRecord::RecordInvalid => e
      puts "  WARNING: Could not update machine '#{machine.name}': #{e.message}"
      nil
    end
  end
end

namespace :pworld do
  desc "Import shops from P-WORLD (all 47 prefectures)"
  task import_shops: :environment do
    puts "=" * 60
    puts "P-WORLD Shop Import - All Prefectures"
    puts "=" * 60

    start_time = Time.current
    total_new = 0
    errors = []

    Prefecture.order(:id).each do |prefecture|
      begin
        count = PworldScraper.import_shops_for_prefecture(prefecture)
        total_new += count
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { prefecture: prefecture.name, error: e.message }
        puts "  ERROR for #{prefecture.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Import complete in #{elapsed}s"
    puts "  Total new shops: #{total_new}"
    puts "  Total shops in DB: #{Shop.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:prefecture]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import shops from P-WORLD (single prefecture by slug, e.g. rake pworld:import_prefecture[tokyo])"
  task :import_prefecture, [:slug] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "ERROR: Please provide a prefecture slug."
      puts "Usage: rake pworld:import_prefecture[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)

    unless prefecture
      puts "ERROR: Prefecture with slug '#{slug}' not found."
      puts "Available: #{Prefecture.pluck(:slug).join(', ')}"
      exit 1
    end

    puts "=" * 60
    puts "P-WORLD Shop Import - #{prefecture.name}"
    puts "=" * 60

    start_time = Time.current
    count = PworldScraper.import_shops_for_prefecture(prefecture)
    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Import complete in #{elapsed}s"
    puts "  New shops imported: #{count}"
    puts "  Total shops for #{prefecture.name}: #{prefecture.shops.count}"
    puts "=" * 60
  end

  desc "Import installed machines for all shops (links machines to shops via ShopMachineModel)"
  task import_shop_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Shop Machine Import"
    puts "=" * 60

    start_time = Time.current
    total_linked = 0
    total_shops = Shop.count
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        count = PworldScraper.import_machines_for_shop(shop)
        total_linked += count
        puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{count} new machines linked" if count > 0
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Shop machine import complete in #{elapsed}s"
    puts "  Total new links: #{total_linked}"
    puts "  Total shop-machine links in DB: #{ShopMachineModel.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import installed machines for shops in a prefecture (by slug, e.g. rake pworld:import_shop_machines_by_pref[fukuoka])"
  task :import_shop_machines_by_pref, [:slug] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:import_shop_machines_by_pref[fukuoka]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Shop Machine Import - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_linked = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        count = PworldScraper.import_machines_for_shop(shop)
        total_linked += count
        puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{count} new machines linked" if count > 0
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} import complete in #{elapsed}s"
    puts "  Total new links: #{total_linked}"
    puts "  Total shop-machine links for #{prefecture.name}: #{ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id }).count}"
    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end
    puts "=" * 60
  end

  desc "Import installed machines for a single shop (by slug)"
  task :import_shop_machines_for, [:slug] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:import_shop_machines_for[shop-slug]"
      exit 1
    end

    shop = Shop.includes(:prefecture).find_by(slug: slug)
    unless shop
      puts "ERROR: Shop '#{slug}' not found."
      exit 1
    end

    count = PworldScraper.import_machines_for_shop(shop)
    puts "#{shop.name}: #{count} new machines linked (#{shop.machine_models.count} total)"
  end

  desc "Weekly refresh: sync shop-machine links for all shops (add new, remove stale)"
  task refresh_shop_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Weekly Refresh - Shop Machine Links"
    puts "=" * 60

    start_time = Time.current
    total_added = 0
    total_removed = 0
    total_shops = Shop.count
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        result = PworldScraper.refresh_machines_for_shop(shop)
        total_added += result[:added]
        total_removed += result[:removed]
        if result[:added] > 0 || result[:removed] > 0
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: +#{result[:added]} -#{result[:removed]}"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Refresh complete in #{elapsed}s"
    puts "  Added: #{total_added}, Removed: #{total_removed}"
    puts "  Total shop-machine links: #{ShopMachineModel.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Weekly refresh: sync shop-machine links for a prefecture (e.g. rake pworld:refresh_by_pref[tokyo])"
  task :refresh_by_pref, [:slug] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:refresh_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.includes(:prefecture).order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Weekly Refresh - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_added = 0
    total_removed = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        result = PworldScraper.refresh_machines_for_shop(shop)
        total_added += result[:added]
        total_removed += result[:removed]
        if result[:added] > 0 || result[:removed] > 0
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: +#{result[:added]} -#{result[:removed]}"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} refresh complete in #{elapsed}s"
    puts "  Added: #{total_added}, Removed: #{total_removed}"
    puts "  Total links for #{prefecture.name}: #{ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id }).count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Deactivate machines with no shop links (cleanup after refresh)"
  task cleanup_orphan_machines: :environment do
    orphans = MachineModel.active
      .left_joins(:shop_machine_models)
      .group("machine_models.id")
      .having("COUNT(shop_machine_models.id) = 0")

    count = orphans.count.size
    if count > 0
      orphan_ids = orphans.pluck(:id)
      MachineModel.where(id: orphan_ids).update_all(active: false)
      puts "Deactivated #{count} orphan machines (no shop links)"
    else
      puts "No orphan machines found"
    end
  end

  desc "Scrape shop details (machine counts, business hours, pworld_url) for all shops"
  task scrape_shop_details: :environment do
    $stdout.sync = true
    puts "=" * 60
    puts "P-WORLD Shop Details Scrape - All Shops"
    puts "=" * 60

    start_time = Time.current
    total_shops = Shop.count
    total_updated = 0
    total_skipped = 0
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        data = PworldScraper.scrape_shop_details(shop)
        if data
          has_data = data.keys.any? { |k| k != :pworld_url && data[k].present? }
          if has_data
            total_updated += 1
            parts = []
            parts << "slot:#{data[:slot_machines]}" if data[:slot_machines]
            parts << data[:business_hours] if data[:business_hours]
            parts << "P:#{data[:parking_spaces]}台" if data[:parking_spaces]
            parts << "朝:#{data[:morning_entry].to_s[0..20]}" if data[:morning_entry]
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{parts.join(' | ')}"
          else
            total_skipped += 1
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: (no data)"
          end
        else
          total_skipped += 1
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: (fetch failed)"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Shop details scrape complete in #{elapsed}s"
    puts "  Updated: #{total_updated}, Skipped: #{total_skipped}"
    puts "  Shops with slot_machines: #{Shop.where.not(slot_machines: nil).count}"
    puts "  Shops with business_hours: #{Shop.where.not(business_hours: [nil, '']).count}"
    puts "  Shops with parking_spaces: #{Shop.where.not(parking_spaces: nil).count}"
    puts "  Shops with morning_entry: #{Shop.where.not(morning_entry: [nil, '']).count}"
    puts "  Shops with phone_number: #{Shop.where.not(phone_number: [nil, '']).count}"
    puts "  Shops with pworld_url: #{Shop.where.not(pworld_url: [nil, '']).count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Scrape shop details for a prefecture (e.g. rake pworld:scrape_shop_details_by_pref[tokyo])"
  task :scrape_shop_details_by_pref, [:slug] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:scrape_shop_details_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      puts "Available: #{Prefecture.pluck(:slug).join(', ')}"
      exit 1
    end

    shops = prefecture.shops.order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Shop Details Scrape - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        data = PworldScraper.scrape_shop_details(shop)
        if data
          has_data = data[:slot_machines] || data[:business_hours]
          if has_data
            total_updated += 1
            slots = data[:slot_machines] ? "slot:#{data[:slot_machines]}" : "-"
            total = data[:total_machines] ? "total:#{data[:total_machines]}" : "-"
            hours = data[:business_hours] || "-"
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{slots} #{total} #{hours}"
          else
            total_skipped += 1
          end
        else
          total_skipped += 1
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    pref_shops = prefecture.shops
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} shop details scrape complete in #{elapsed}s"
    puts "  Updated: #{total_updated}, Skipped: #{total_skipped}"
    puts "  Shops with slot_machines: #{pref_shops.where.not(slot_machines: nil).count}/#{total_shops}"
    puts "  Shops with business_hours: #{pref_shops.where.not(business_hours: [nil, '']).count}/#{total_shops}"
    puts "  Shops with pworld_url: #{pref_shops.where.not(pworld_url: [nil, '']).count}/#{total_shops}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import slot machine models from P-WORLD type listings"
  task import_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Machine Model Import"
    puts "=" * 60

    start_time = Time.current

    # Import from slot type listings
    PworldScraper.import_slot_machines

    # Also import from the new machine schedule
    sleep(PworldScraper::REQUEST_INTERVAL)
    PworldScraper.import_new_machines_from_schedule

    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Machine import complete in #{elapsed}s"
    puts "  Total machine models in DB: #{MachineModel.count}"
    puts "=" * 60
  end

  desc "Flag smart slot machines using P-WORLD over_6.5number listing + name patterns"
  task flag_smart_slots: :environment do
    $stdout.sync = true
    puts "=" * 60
    puts "P-WORLD Smart Slot Flagging"
    puts "=" * 60

    before_count = MachineModel.where(is_smart_slot: true).count
    puts "Before: #{before_count} smart slots flagged"
    puts ""

    PworldScraper.flag_smart_slots

    after_count = MachineModel.where(is_smart_slot: true).count
    puts ""
    puts "After: #{after_count} smart slots flagged (+#{after_count - before_count} new)"

    # Show display_type distribution
    puts ""
    puts "=== Display type distribution (active only) ==="
    MachineModel.active.find_each.group_by(&:display_type).sort_by { |k, _| MachineModel::DISPLAY_TYPES[k][:sort] }.each do |type, machines|
      puts "  #{MachineModel::DISPLAY_TYPES[type][:label]}: #{machines.size}"
    end
    puts "  合計: #{MachineModel.active.count}"
    puts "=" * 60
  end

  desc "Fetch pworld_machine_id for all machines from P-WORLD type listings"
  task fetch_machine_ids: :environment do
    $stdout.sync = true
    puts "=" * 60
    puts "P-WORLD Machine ID Fetch"
    puts "=" * 60

    start_time = Time.current
    before_count = MachineModel.where.not(pworld_machine_id: nil).count

    PworldScraper.fetch_machine_ids

    after_count = MachineModel.where.not(pworld_machine_id: nil).count
    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Machine ID fetch complete in #{elapsed}s"
    puts "  Before: #{before_count}, After: #{after_count} (+#{after_count - before_count})"
    puts "  Total machines: #{MachineModel.count}"
    puts "=" * 60
  end

  desc "Scrape machine details from P-WORLD (generation, payout, image, etc). Optional: rake pworld:scrape_machine_details[100]"
  task :scrape_machine_details, [:limit] => :environment do |_t, args|
    $stdout.sync = true
    limit = args[:limit]&.to_i

    machines = MachineModel.where.not(pworld_machine_id: nil)
    machines = machines.where(generation: nil).or(machines.where(type_detail: nil))
    machines = machines.order(:id)
    machines = machines.limit(limit) if limit

    total = machines.count
    puts "=" * 60
    puts "P-WORLD Machine Details Scrape#{limit ? " (limit: #{limit})" : ""}"
    puts "  Target: #{total} machines"
    puts "=" * 60

    start_time = Time.current
    updated = 0
    skipped = 0
    errors = []

    machines.find_each.with_index do |machine, index|
      begin
        data = PworldScraper.scrape_machine_detail(machine)
        if data && data.any? { |k, v| k != :is_smart_slot && v.present? }
          updated += 1
          parts = []
          parts << data[:generation] if data[:generation]
          parts << "#{data[:payout_rate_min]}~#{data[:payout_rate_max]}%" if data[:payout_rate_min]
          parts << data[:introduced_on].to_s if data[:introduced_on]
          puts "  [#{index + 1}/#{total}] #{machine.name}: #{parts.join(' | ')}"
        else
          skipped += 1
          puts "  [#{index + 1}/#{total}] #{machine.name}: (no data)" if (index + 1) <= 20 || (index + 1) % 100 == 0
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { machine: machine.name, error: e.message }
        puts "  ERROR for #{machine.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Machine details scrape complete in #{elapsed}s"
    puts "  Updated: #{updated}, Skipped: #{skipped}, Errors: #{errors.size}"
    puts "  With generation: #{MachineModel.where.not(generation: nil).count}"
    puts "  With payout: #{MachineModel.where.not(payout_rate_min: nil).count}"
    puts "  With image: #{MachineModel.where.not(image_url: [nil, '']).count}"
    puts "  With introduced_on: #{MachineModel.where.not(introduced_on: nil).count}"
    puts "  With certification: #{MachineModel.where.not(certification_number: [nil, '']).count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.first(10).each { |e| puts "    - #{e[:machine]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  # ── 定期更新バッチ ─────────────────────────────────────
  desc "Weekly update: refresh machine links for all shops (run every Sunday)"
  task weekly_refresh: :environment do
    $stdout.sync = true
    require_relative "../batch_logger"

    BatchLogger.with_logging("weekly_refresh") do |blog|
      machines_before = MachineModel.active.count
      links_before = ShopMachineModel.count

      # 1. 新台チェック
      blog.info "[Step 1/3] Checking for new machines..."
      begin
        PworldScraper.import_new_machines_from_schedule
      rescue => e
        blog.error "New machine import failed: #{e.message}"
      end
      new_machines = MachineModel.active.count - machines_before
      blog.info "  New machines added: #{new_machines}"

      # 2. 全店舗の設置機種リスト更新 (各県順番に)
      blog.info "[Step 2/3] Refreshing shop-machine links..."
      total_added = 0
      total_removed = 0
      shop_errors = 0
      Prefecture.order(:id).each do |pref|
        shops = pref.shops.where.not(pworld_url: [nil, ""])
        next if shops.empty?

        blog.info "  #{pref.name} (#{shops.count}店)..."
        shops.find_each do |shop|
          begin
            result = PworldScraper.refresh_machines_for_shop(shop)
            if result
              total_added += result[:added]
              total_removed += result[:removed]
            end
          rescue => e
            shop_errors += 1
            blog.error "Shop #{shop.name} (#{shop.id}) failed: #{e.message}" if shop_errors <= 20
          end
          sleep(PworldScraper::REQUEST_INTERVAL)
        end
      end
      blog.info "  Links added: #{total_added}, removed: #{total_removed}"

      # 3. 孤立機種のクリーンアップ
      blog.info "[Step 3/3] Cleaning up orphan machines..."
      orphans = MachineModel.active
        .left_joins(:shop_machine_models)
        .where(shop_machine_models: { id: nil })
      orphan_count = orphans.count
      if orphan_count > 0
        orphans.update_all(active: false)
        blog.info "  Deactivated #{orphan_count} orphan machines"
      else
        blog.info "  No orphans found"
      end

      blog.summary(
        new_machines: new_machines,
        links_added: total_added,
        links_removed: total_removed,
        orphans_deactivated: orphan_count,
        shop_errors: shop_errors,
        active_machines: MachineModel.active.count,
        total_links: ShopMachineModel.count
      )
    end
  end

  desc "Update unit counts for all shops (scrapes P-WORLD number images)"
  task update_unit_counts: :environment do
    $stdout.sync = true

    puts "=" * 60
    puts "P-WORLD Unit Count Update - All Shops"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    total_shops = Shop.where.not(pworld_url: [nil, ""]).count
    errors = []
    processed = 0

    Shop.includes(:prefecture).where.not(pworld_url: [nil, ""]).find_each do |shop|
      processed += 1
      begin
        result = PworldScraper.scrape_unit_counts_for_shop(shop)
        if result
          total_updated += result[:updated]
          total_skipped += result[:skipped]
          if result[:updated] > 0
            puts "  [#{processed}/#{total_shops}] #{shop.name}: #{result[:updated]} machines updated"
          end
        else
          puts "  [#{processed}/#{total_shops}] #{shop.name}: SKIP (page not found)"
        end
        # Rate limit: page fetch (2.5s) + digit image downloads (~10 images * minimal time)
        # The page fetch already sleeps via fetch_page, but add interval for safety
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    with_count = ShopMachineModel.where.not(unit_count: [nil, 0]).count
    total_links = ShopMachineModel.count

    puts ""
    puts "=" * 60
    puts "Unit count update complete in #{elapsed}s"
    puts "  Updated: #{total_updated} machines across #{processed} shops"
    puts "  Skipped (no ShopMachineModel): #{total_skipped}"
    puts "  Coverage: #{with_count}/#{total_links} (#{(with_count * 100.0 / total_links).round(1)}%)"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.first(20).each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
      puts "    ... and #{errors.size - 20} more" if errors.size > 20
    end

    puts "=" * 60
  end

  desc "Update unit counts for a prefecture (e.g. rake pworld:update_unit_counts_by_pref[tokyo])"
  task :update_unit_counts_by_pref, [:slug] => :environment do |_t, args|
    $stdout.sync = true
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:update_unit_counts_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.where.not(pworld_url: [nil, ""]).order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Unit Count Update - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        result = PworldScraper.scrape_unit_counts_for_shop(shop)
        if result
          total_updated += result[:updated]
          total_skipped += result[:skipped]
          if result[:updated] > 0
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{result[:updated]} machines updated"
          end
        else
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: SKIP (page not found)"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    pref_links = ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id })
    with_count = pref_links.where.not(unit_count: [nil, 0]).count
    total_links = pref_links.count

    puts ""
    puts "=" * 60
    puts "#{prefecture.name} unit count update complete in #{elapsed}s"
    puts "  Updated: #{total_updated} machines across #{total_shops} shops"
    puts "  Skipped (no ShopMachineModel): #{total_skipped}"
    puts "  Coverage: #{with_count}/#{total_links} (#{total_links > 0 ? (with_count * 100.0 / total_links).round(1) : 0}%)"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.first(20).each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Monthly update: refresh shop details from P-WORLD (営業時間, 駐車場, 設備等)"
  task monthly_refresh: :environment do
    $stdout.sync = true
    require_relative "../batch_logger"

    BatchLogger.with_logging("monthly_refresh") do |blog|
      shops_before = Shop.where.not(business_hours: [nil, ""]).count

      blog.info "Refreshing shop details for all shops..."
      Rake::Task["pworld:scrape_shop_details"].invoke

      shops_after = Shop.where.not(business_hours: [nil, ""]).count
      total_shops = Shop.count
      rate_coverage = Shop.where.not(slot_rates: [nil, [], [""]]).count
      parking_coverage = Shop.where.not(parking_spaces: [nil, ""]).count

      blog.summary(
        total_shops: total_shops,
        shops_with_hours_before: shops_before,
        shops_with_hours_after: shops_after,
        rate_coverage: "#{(rate_coverage * 100.0 / total_shops).round(1)}% (#{rate_coverage}/#{total_shops})",
        parking_coverage: "#{(parking_coverage * 100.0 / total_shops).round(1)}% (#{parking_coverage}/#{total_shops})"
      )
    end
  end
end
